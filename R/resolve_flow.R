#' Enumerate the structural paths through the survey flow
#'
#' Walks the `SurveyFlow`, forking at every `Branch` into feasible outcomes.
#' When consecutive branches test the same embedded-data field for equality
#' against different values, they are recognised as mutually exclusive and
#' enumerated as one-of-k (plus a "none matches" fallback) instead of 2^k
#' independent binary decisions. All other branches are still forked into a
#' condition-true and a condition-false path. The result is the *structural
#' path space* -- every block sequence a respondent could encounter -- without
#' any assumption about branch probabilities.
#'
#' Within-block display logic (whether an individual question is shown) is *not*
#' resolved here; that is a separate step. Paths are at block granularity.
#'
#' @param qsf A `qsf_raw` object from [read_qsf()].
#' @param max_paths Cap on the number of distinct paths. If the flow would
#'   produce more, an error is raised rather than a partial result.
#'
#' @return A [tibble][tibble::tibble], one row per distinct path:
#'   \describe{
#'     \item{path_id}{Integer id.}
#'     \item{block_ids}{List column: ordered `BL_...` ids the path shows.}
#'     \item{terminates_early}{`TRUE` if the path hits an `EndSurvey` before the
#'       end of the flow (a screen-out or quota termination).}
#'     \item{decisions}{List column: named logical vector, one entry per branch
#'       on one combination of branch outcomes that produces this path, `TRUE` =
#'       condition taken.}
#'   }
#'
#' @examples
#' qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
#'                          package = "surveyBurden")
#' flow <- resolve_flow(read_qsf(qsf_path))
#' flow[, c("path_id", "terminates_early")]
#'
#' @export
resolve_flow <- function(qsf, max_paths = 10000L) {
  if (!inherits(qsf, "qsf_raw")) {
    cli::cli_abort("{.arg qsf} must be a {.cls qsf_raw} object from {.fn read_qsf}.")
  }
  enumerate_paths(qsf_flow(qsf)[["Flow"]], max_paths = max_paths)
}

#' Extract the grouping key from a Branch node, if it is a simple single-literal
#' EmbeddedField equality check. Returns `list(field = <LeftOperand>)` or NULL.
#' @noRd
extract_branch_key <- function(node) {
  bl <- node[["BranchLogic"]]
  if (!is.list(bl)) return(NULL)
  group_keys <- setdiff(names(bl), c("Type", "inPage"))
  if (length(group_keys) != 1L) return(NULL)
  g <- bl[[group_keys[1]]]
  lit_keys <- setdiff(names(g), "Type")
  if (length(lit_keys) != 1L) return(NULL)
  lit <- g[[lit_keys[1]]]
  if (!identical(lit[["LogicType"]] %||% "", "EmbeddedField")) return(NULL)
  if (!identical(lit[["Operator"]] %||% "", "EqualTo")) return(NULL)
  field <- lit[["LeftOperand"]] %||% ""
  if (nchar(field) == 0L) return(NULL)
  list(field = field)
}

#' Replace runs of consecutive mutually exclusive Branch nodes with a single
#' synthetic ExclusiveBranchGroup node. A run qualifies when every Branch in
#' it is a simple single-literal EmbeddedField EqualTo check on the same field.
#' Recurses into Group, Authenticator, and BlockRandomizer child flows.
#' @noRd
collapse_exclusive_branches <- function(nodes) {
  if (length(nodes) == 0L) return(nodes)
  # Recurse into container nodes first
  nodes <- lapply(nodes, function(n) {
    tp <- n[["Type"]] %||% ""
    if (tp %in% c("Group", "Authenticator", "BlockRandomizer", "Branch") &&
        is.list(n[["Flow"]])) {
      n[["Flow"]] <- collapse_exclusive_branches(n[["Flow"]])
    }
    n
  })
  out <- list()
  i <- 1L
  while (i <= length(nodes)) {
    node <- nodes[[i]]
    if (!identical(node[["Type"]] %||% "", "Branch")) {
      out[[length(out) + 1L]] <- node
      i <- i + 1L
      next
    }
    key <- extract_branch_key(node)
    if (is.null(key)) {
      out[[length(out) + 1L]] <- node
      i <- i + 1L
      next
    }
    run <- list(node)
    j <- i + 1L
    while (j <= length(nodes) &&
           identical(nodes[[j]][["Type"]] %||% "", "Branch")) {
      k2 <- extract_branch_key(nodes[[j]])
      if (is.null(k2) || !identical(k2$field, key$field)) break
      run[[length(run) + 1L]] <- nodes[[j]]
      j <- j + 1L
    }
    if (length(run) >= 2L) {
      fids <- vapply(run, function(b) b[["FlowID"]] %||% "branch", character(1))
      out[[length(out) + 1L]] <- list(
        Type     = "ExclusiveBranchGroup",
        branches = run,
        field    = key$field,
        FlowID   = paste0("XG:", paste(fids, collapse = "+"))
      )
    } else {
      out[[length(out) + 1L]] <- node
    }
    i <- j
  }
  out
}

#' Enumerate paths from a bare list of flow nodes. Internal; see [resolve_flow()].
#'
#' Uses a memoised set-of-outcomes recursion: `outcomes(remaining)` is the set of
#' `(future block sequence, terminated early)` pairs reachable from a flow
#' position, independent of what came before. Memoising on the remaining-node
#' sequence collapses the branch explosion (many branches only set embedded data
#' and do not change the block sequence).
#' @noRd
enumerate_paths <- function(nodes, max_paths = 10000L) {
  nodes <- collapse_exclusive_branches(nodes)
  exclusive_fields <- character(0)

  memo <- new.env(parent = emptyenv())
  randomisers <- character(0)   # collected, warned about once (see below)

  key_of <- function(remaining) {
    paste(vapply(remaining, function(n) n$FlowID %||% n$Type %||% "?", character(1)),
          collapse = ",")
  }
  # Each outcome carries `bkey` == paste(blocks, collapse = ">"), built one
  # block at a time as outcomes are extended, so dedupe never re-collapses a
  # whole block sequence.
  dedupe <- function(outs) {
    keys <- vapply(outs, function(o) paste0(o$bkey, "|", o$early), character(1))
    outs[!duplicated(keys)]
  }
  annotate <- function(outs, fid, value) {
    lapply(outs, function(o) {
      o$decisions <- c(stats::setNames(list(value), fid), o$decisions)
      o
    })
  }

  outcomes <- function(remaining) {
    if (length(remaining) == 0L) {
      return(list(list(blocks = character(0), bkey = "", early = FALSE, decisions = list())))
    }
    key <- key_of(remaining)
    hit <- memo[[key]]
    if (!is.null(hit)) return(hit)

    node <- remaining[[1]]
    rest <- remaining[-1]
    type <- node$Type %||% NA_character_

    res <- if (type %in% c("Standard", "Block")) {
      id <- node$ID %||% NA_character_
      lapply(outcomes(rest), function(o) {
        o$bkey <- if (length(o$blocks)) paste0(id, ">", o$bkey) else paste(id)
        o$blocks <- c(id, o$blocks)
        o
      })
    } else if (type == "EmbeddedData") {
      outcomes(rest)
    } else if (type == "EndSurvey") {
      list(list(blocks = character(0), bkey = "", early = length(rest) > 0L, decisions = list()))
    } else if (type == "ExclusiveBranchGroup") {
      branches <- node$branches
      exclusive_fields <<- c(exclusive_fields, node$field)
      all_outs <- list()
      for (bi in seq_along(branches)) {
        b <- branches[[bi]]
        fid <- b[["FlowID"]] %||% "branch"
        outs <- annotate(outcomes(c(b[["Flow"]] %||% list(), rest)), fid, TRUE)
        for (oi in seq_along(branches)) {
          if (oi == bi) next
          ofid <- branches[[oi]][["FlowID"]] %||% "branch"
          outs <- annotate(outs, ofid, FALSE)
        }
        all_outs <- c(all_outs, outs)
      }
      # "none fires" fallback: all branches FALSE
      none <- outcomes(rest)
      for (b in branches) {
        fid <- b[["FlowID"]] %||% "branch"
        none <- annotate(none, fid, FALSE)
      }
      c(all_outs, none)
    } else if (type == "Branch") {
      fid <- node$FlowID %||% "branch"
      taken <- annotate(outcomes(c(node[["Flow"]] %||% list(), rest)), fid, TRUE)
      not   <- annotate(outcomes(rest), fid, FALSE)
      c(taken, not)   # deduped with every other node type below
    } else if (type %in% c("Group", "Authenticator")) {
      # an Authenticator wraps the flow shown once a respondent authenticates;
      # failed authentication never yields a response, so only that flow counts
      outcomes(c(node[["Flow"]] %||% list(), rest))
    } else if (type == "BlockRandomizer") {
      randomisers <<- c(randomisers, node$FlowID %||% node$ID %||% "BlockRandomizer")
      outcomes(c(node[["Flow"]] %||% list(), rest))
    } else {
      cli::cli_warn("Unhandled flow node type {.val {type}}; skipping.")
      outcomes(rest)
    }

    res <- dedupe(res)
    if (length(res) > max_paths) {
      cli::cli_abort(c(
        "This survey's path space is too large to enumerate.",
        i = "More than {max_paths} distinct paths; the flow has {count_branches(nodes)} branches.",
        i = "Raise {.arg max_paths} (e.g. {.code burden_report(x, max_paths = 50000)}) or treat this as a diagnostic finding (intractable routing)."
      ))
    }
    memo[[key]] <- res
    res
  }

  paths <- dedupe(outcomes(nodes))

  exclusive_fields <- unique(exclusive_fields)
  if (length(exclusive_fields)) {
    cli::cli_inform(c(
      i = paste("Mutually exclusive branches detected on embedded",
                "field{?s} {.val {exclusive_fields}}; enumerating one-of-k",
                "instead of 2^k.")
    ))
  }

  randomisers <- unique(randomisers)
  if (length(randomisers)) {
    cli::cli_warn(c(
      paste("{length(randomisers)} BlockRandomizer{?s} in the flow; treating all",
            "sub-blocks as shown, in survey order (randomised subsets not enumerated)."),
      i = "Affected flow node{?s}: {.val {randomisers}}"
    ))
  }

  tibble::tibble(
    path_id          = seq_along(paths),
    block_ids        = lapply(paths, function(p) p$blocks),
    terminates_early = vapply(paths, function(p) p$early, logical(1)),
    decisions        = lapply(paths, function(p) {
      d <- p$decisions
      if (length(d) == 0L) logical(0) else unlist(d)
    })
  )
}

#' Count Branch nodes anywhere in a flow-node list
#' @noRd
count_branches <- function(nodes) {
  n <- 0L
  flow_walk(nodes, function(node) if (identical(node$Type, "Branch")) n <<- n + 1L)
  n
}
