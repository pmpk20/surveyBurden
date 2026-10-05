#' Parse a Qualtrics DisplayLogic tree into an evaluable predicate
#'
#' The tree has numbered groups, each holding numbered literals combined
#' left-to-right by their `Conjuction` field ("And"/"Or"; first literal has
#' none). Groups are combined by their `Type` field, with `"AndIf"` binding
#' before `"ElseIf"`: `If G0 / ElseIf G1 / AndIf G2` is `G0 OR (G1 AND G2)`
#' (see [combine_groups()]). A group whose `Type` is missing joins as AND.
#' This parser produces the
#' set of gate variables the logic reads and a function that evaluates the
#' logic against an assignment of those variables.
#'
#' Approximations (documented, for the enumeration in [path_burden_profile()]):
#' \itemize{
#'   \item `EmbeddedField` and `LoopAndMerge` literals become a free binary gate
#'     (the actual comparison is not evaluated -- both outcomes are enumerated).
#'   \item Unrecognised question operators also become a free binary gate.
#' }
#'
#' @param dl A `Payload$DisplayLogic` list.
#'
#' @return `list(vars, predicate)`. `vars` is a character vector of gate names
#'   (a `QID` for question literals, `"@<operand>"` for free gates). `predicate`
#'   is `function(state, shown = NULL)`: `state[[qid]]` is a character vector of
#'   selected choice-locator tails; `state[["@x"]]` is a logical; `shown[[qid]]`
#'   is whether that question was displayed (for the `Displayed` operator).
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
  parsed_groups <- lapply(groups, function(lits) {
    lapply(lits, function(lit) {
      pl <- parse_literal(lit)
      vars <<- c(vars, pl$var)
      if (!is.null(pl$ref_tail) && !startsWith(pl$var, "@")) {
        refs[[pl$var]] <<- unique(c(refs[[pl$var]], pl$ref_tail))
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
      acc <- lit_val(lits[[1]])
      for (k in seq_along(lits)[-1]) {
        v <- lit_val(lits[[k]])
        acc <- if (identical(lits[[k]]$conj, "Or")) acc || v else acc && v
      }
      acc
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
      acc <- lit_val(lits[[1]])
      for (k in seq_along(lits)[-1]) {
        v <- lit_val(lits[[k]])
        acc <- if (identical(lits[[k]]$conj, "Or")) acc | v else acc & v
      }
      acc
    }, logical(1))
    !isFALSE(combine_groups(as.list(group_vals), group_types))
  }

  displayed <- unlist(lapply(parsed_groups, function(lits)
    unlist(lapply(lits, function(pl) pl$displayed_qid))))

  list(vars = unique(vars), predicate = predicate, refs = refs,
       displayed = unique(displayed), possible = possible)
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

  # EmbeddedField / LoopAndMerge / anything else -> free binary gate
  fv <- paste0("@", lit$LeftOperand %||% "field")
  list(var = fv, conj = conj, eval = function(state, shown) isTRUE(state[[fv]]))
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
