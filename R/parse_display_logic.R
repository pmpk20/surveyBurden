#' Parse a Qualtrics DisplayLogic tree into an evaluable predicate
#'
#' The tree has numbered groups, each holding numbered literals combined by
#' their `Conjuction` field ("And"/"Or"; first literal has none), with And
#' binding before Or: `A Or B And C` is `A | (B & C)` (see
#' [combine_literals()]). Groups are combined by their `Type` field, with `"AndIf"` binding
#' before `"ElseIf"`: `If G0 / ElseIf G1 / AndIf G2` is `G0 OR (G1 AND G2)`
#' (see [combine_groups()]). A group whose `Type` is missing joins as AND.
#' This parser produces the
#' set of gate variables the logic reads and a function that evaluates the
#' logic against an assignment of those variables.
#'
#' Stored fields: an `EmbeddedField` literal whose operator is a comparison
#' (`EqualTo`, `NotEqualTo`, `GreaterThan`, `GreaterThanOrEqual`, `LessThan`,
#' `LessThanOrEqual`) is evaluated against a value of the field: gate
#' `"@<field>"`, whose states are the field's distinguishable value classes
#' (see `field_value_classes()`), so literals on the same field are evaluated
#' jointly.
#'
#' Approximations (documented, for the enumeration in [path_burden_profile()]):
#' \itemize{
#'   \item `EmbeddedField` literals with any other operator become a free
#'     binary gate `"@?<field>"` (the comparison is not evaluated -- both
#'     outcomes are enumerated); [calculation_certainty()] counts them.
#'   \item `LoopAndMerge` literals and unrecognised question operators also
#'     become a free binary gate.
#' }
#'
#' @param dl A `Payload$DisplayLogic` list.
#'
#' @return `list(vars, predicate)`. `vars` is a character vector of gate names
#'   (a `QID` for question literals, `"@<field>"` for evaluable stored fields,
#'   `"@?<field>"` or `"@<operand>"` for free gates). `predicate` is
#'   `function(state, shown = NULL)`: `state[[qid]]` is a character vector of
#'   selected choice-locator tails; `state[["@<field>"]]` is the field's value
#'   (`NA` when empty); a free gate's state is a logical; `shown[[qid]]` is
#'   whether that question was displayed (for the `Displayed` operator).
#'   `fields` maps each evaluable field gate to its `(op, value)` comparisons.
#' @noRd
parse_display_logic <- function(dl) {
  group_keys <- setdiff(names(dl), c("Type", "inPage"))
  # how each group joins the ones before it (see combine_groups()): "AndIf"
  # or a missing type -> AND; "ElseIf" (or anything else) -> OR. Index 1 is
  # the base and is never consulted.
  group_types <- unname(vapply(group_keys,
                               function(gk) dl[[gk]]$Type %||% NA_character_,
                               character(1)))
  groups <- lapply(group_keys, function(gk) {
    g <- dl[[gk]]
    lit_keys <- setdiff(names(g), "Type")
    lapply(lit_keys, function(lk) g[[lk]])
  })

  vars <- character(0)
  refs <- list()
  fields <- list()
  parsed_groups <- lapply(groups, function(lits) {
    lapply(lits, function(lit) {
      pl <- parse_literal(lit)
      vars <<- c(vars, pl$var)
      if (!is.null(pl$ref_tail) && !startsWith(pl$var, "@")) {
        refs[[pl$var]] <<- unique(c(refs[[pl$var]], pl$ref_tail))
      }
      if (!is.null(pl$field_cmp)) {
        fields[[pl$var]] <<- c(fields[[pl$var]], list(pl$field_cmp))
      }
      pl
    })
  })

  predicate <- function(state, shown = NULL, permissive = character(0)) {
    if (is.null(shown)) shown <- logical(0)
    lit_val <- function(pl) {
      if (length(permissive) && pl$var %in% permissive) return(TRUE)
      pl$eval(state, shown)
    }
    group_vals <- vapply(parsed_groups, function(lits) {
      combine_literals(lapply(lits, lit_val), lit_conjs(lits))
    }, logical(1))
    isTRUE(combine_groups(as.list(group_vals), group_types))
  }

  # Can the logic be TRUE on a path where the questions in `off_path` are never
  # shown? Those questions are unanswered and not displayed, so their literals
  # have a fixed value; every other literal is unknown (NA). Combining with
  # R's three-valued `&` / `|`, only a definite FALSE rules the question out.
  # Unknown literals are treated as independent, so this errs towards TRUE
  # ("may be shown"), never towards a wrong "never shown".
  possible <- function(off_path) {
    lit_val <- function(pl) {
      if (startsWith(pl$var, "@") || !pl$var %in% off_path) return(NA)
      pl$eval(list(), c())
    }
    group_vals <- vapply(parsed_groups, function(lits) {
      combine_literals(lapply(lits, lit_val), lit_conjs(lits))
    }, logical(1))
    !isFALSE(combine_groups(as.list(group_vals), group_types))
  }

  displayed <- unlist(lapply(parsed_groups, function(lits)
    unlist(lapply(lits, function(pl) pl$displayed_qid))))

  loop_blocks <- unlist(lapply(parsed_groups, function(lits)
    unlist(lapply(lits, function(pl) pl$loop_block))))

  list(vars = unique(vars), predicate = predicate, refs = refs, fields = fields,
       displayed = unique(displayed), possible = possible,
       loop_blocks = unique(loop_blocks))
}

#' Parse one literal into `list(var, conj, eval)`
#' @noRd
parse_literal <- function(lit) {
  conj <- lit$Conjuction %||% NULL
  logic_type <- lit$LogicType %||% "Question"
  op <- lit$Operator %||% "Selected"

  if (identical(logic_type, "Question")) {
    qid <- lit$QuestionID %||% sub("^q://(QID[0-9]+).*", "\\1", lit$LeftOperand %||% "")
    tail <- sub("^q://QID[0-9]+/SelectableChoice/", "", lit$ChoiceLocator %||% lit$LeftOperand %||% "")

    if (op %in% c("Selected", "NotSelected")) {
      ev <- function(state, shown) {
        hit <- tail %in% (state[[qid]] %||% character(0))
        if (identical(op, "NotSelected")) !hit else hit
      }
      return(list(var = qid, conj = conj, eval = ev, ref_tail = tail))
    }
    if (op %in% c("Displayed", "NotDisplayed")) {
      ev <- function(state, shown) {
        # `shown` may be a list or a named logical, and may not carry `qid`
        # (e.g. the referenced question is itself conditional and unresolved).
        d <- isTRUE(if (qid %in% names(shown)) shown[[qid]] else FALSE)
        if (identical(op, "NotDisplayed")) !d else d
      }
      return(list(var = qid, conj = conj, eval = ev, displayed_qid = qid))
    }
    # unrecognised question operator -> free binary gate
    fv <- paste0("@", lit$LeftOperand %||% qid)
    return(list(var = fv, conj = conj,
                eval = function(state, shown) isTRUE(state[[fv]])))
  }

  field <- lit$LeftOperand %||% ""
  if (identical(logic_type, "EmbeddedField") && nzchar(field)) {
    if (op %in% branch_ops) {
      # evaluated against the field's value; literals on one field share a gate
      fv  <- paste0("@", field)
      rhs <- as.character(lit$RightOperand %||% "")
      # a gate takes only a few values but is evaluated once per joint state:
      # cache the result per value
      memo <- new.env(parent = emptyenv())
      ev <- function(state, shown) {
        x <- state[[fv]]
        if (is.null(x)) x <- NA_character_
        key <- if (is.na(x)) "\001NA" else x
        hit <- memo[[key]]
        if (is.null(hit)) hit <- memo[[key]] <- eval_branch_op(op, x, rhs)
        hit
      }
      return(list(var = fv, conj = conj, eval = ev,
                  field_cmp = list(op = op, value = rhs)))
    }
    # a comparison we cannot evaluate: free binary gate, kept apart
    fv <- paste0("@?", field)
    return(list(var = fv, conj = conj, eval = function(state, shown) isTRUE(state[[fv]])))
  }

  # Loop position: "Loop k <op> Current Loop" is evaluated from the iteration
  # index the caller supplies as state[["@@iter"]]. Outside a loop Qualtrics
  # leaves lm://CurrentLoop empty, so the literal is FALSE there.
  if (identical(lit$LogicType, "LoopAndMerge") &&
      identical(lit$RightOperand, "lm://CurrentLoop") &&
      grepl("^[^,]+,[0-9]+$", lit$LeftOperand %||% "")) {
    blk <- sub(",[0-9]+$", "", lit$LeftOperand)
    k   <- sub("^.*,", "", lit$LeftOperand)
    op  <- lit$Operator %||% "EqualTo"
    ev <- function(state, shown) {
      j <- state[["@@iter"]]
      if (is.null(j) || length(j) != 1L || is.na(j)) return(FALSE)
      isTRUE(eval_branch_op(op, k, as.character(j)))
    }
    return(list(var = "@@iter", conj = conj, eval = ev, loop_block = blk))
  }

  # LoopAndMerge (other forms) / anything else -> free binary gate
  fv <- paste0("@", lit$LeftOperand %||% "field")
  list(var = fv, conj = conj, eval = function(state, shown) isTRUE(state[[fv]]))
}

#' Conjunctions of parsed literals, `NA` for one without (the first)
#' @noRd
lit_conjs <- function(lits) {
  vapply(lits, function(pl) pl$conj %||% NA_character_, character(1))
}

#' Combine the literal values of one display-logic group the way Qualtrics
#' does: And binds before Or, so `A Or B And C` is `A | (B & C)`. Each "Or"
#' literal starts a new term; any other conjunction ANDs onto the current
#' one. Qualtrics documents this order ("conditions linked by AND are
#' evaluated first, followed by conditions linked by OR"), and on a large
#' export it removed the answered-but-predicted-hidden items that
#' left-to-right evaluation left on questions mixing the two.
#' `vals` is a list of logical vectors (NA allowed: three-valued `&` / `|`);
#' `conjs[k]` is literal k's `Conjuction` (the first is ignored).
#' @noRd
combine_literals <- function(vals, conjs) {
  terms <- list(vals[[1]])
  for (k in seq_along(vals)[-1]) {
    if (identical(conjs[k], "Or")) {
      terms[[length(terms) + 1L]] <- vals[[k]]
    } else {
      terms[[length(terms)]] <- terms[[length(terms)]] & vals[[k]]
    }
  }
  Reduce(`|`, terms)
}

#' Combine display-logic group values the way Qualtrics does: groups joined
#' by "AndIf" (or with no type) bind before groups joined by "ElseIf", so
#' `If G0 / ElseIf G1 / AndIf G2` is `G0 | (G1 & G2)`. On a large Qualtrics
#' export this reading matched which questions respondents answered (99.7%);
#' left-to-right evaluation, `(G0 | G1) & G2`, did not (60%).
#' `vals` is a list of logical vectors (NA allowed: three-valued `&` / `|`);
#' `types[k]` is group k's `Type` (the first is ignored).
#' @noRd
combine_groups <- function(vals, types) {
  terms <- list(vals[[1]])
  for (k in seq_along(vals)[-1]) {
    if (is.na(types[k]) || identical(types[k], "AndIf")) {
      terms[[length(terms)]] <- terms[[length(terms)]] & vals[[k]]
    } else {
      terms[[length(terms) + 1L]] <- vals[[k]]
    }
  }
  Reduce(`|`, terms)
}
