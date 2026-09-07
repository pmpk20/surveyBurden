#' Parse a Qualtrics DisplayLogic tree into an evaluable predicate
#'
#' The tree has numbered groups, each holding numbered literals combined
#' left-to-right by their `Conjuction` field ("And"/"Or"; first literal has
#' none). Groups are combined left-to-right by their `Type` field: the first
#' group is the base, then each `"ElseIf"` group ORs with the running result
#' and each `"AndIf"` group ANDs with it (` ((G0 op1 G1) op2 G2) ... `). A
#' group whose `Type` is missing falls back to AND. This parser produces the
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
  # how each group combines with the running result (see predicate): "AndIf" or
  # a missing type -> AND; "ElseIf" (or anything else) -> OR. Index 1 is the
  # base and is never consulted.
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
    if (length(group_vals) == 1L) return(isTRUE(group_vals[1]))
    acc <- group_vals[1]
    for (k in seq_along(group_vals)[-1]) {
      and_k <- is.na(group_types[k]) || identical(group_types[k], "AndIf")
      acc <- if (and_k) acc && group_vals[k] else acc || group_vals[k]
    }
    isTRUE(acc)
  }

  displayed <- unlist(lapply(parsed_groups, function(lits)
    unlist(lapply(lits, function(pl) pl$displayed_qid))))

  list(vars = unique(vars), predicate = predicate, refs = refs,
       displayed = unique(displayed))
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
