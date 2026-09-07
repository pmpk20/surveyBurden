#' Enumerate feasible respondent paths through the survey flow
#'
#' Walks the `SurveyFlow`, forking at every `Branch` into a condition-true and a
#' condition-false path. Branch conditions are not evaluated: they depend on
#' embedded data or prior answers that are unknown ex ante, so both outcomes are
#' treated as feasible. The result is the *structural path space* -- every block
#' sequence a respondent could encounter -- without any assumption about branch
#' probabilities.
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
#'       on a representative route to this path, `TRUE` = condition taken.}
#'   }
#'
#' @export
resolve_flow <- function(qsf, max_paths = 10000L) {
  if (!inherits(qsf, "qsf_raw")) {
    cli::cli_abort("{.arg qsf} must be a {.cls qsf_raw} object from {.fn read_qsf}.")
  }
  enumerate_paths(qsf_flow(qsf)$Flow, max_paths = max_paths)
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
  memo <- new.env(parent = emptyenv())

  key_of <- function(remaining) {
    paste(vapply(remaining, function(n) n$FlowID %||% n$Type %||% "?", character(1)),
          collapse = ",")
  }
  dedupe <- function(outs) {
    keys <- vapply(outs, function(o) paste0(paste(o$blocks, collapse = ">"), "|", o$early),
                   character(1))
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
      return(list(list(blocks = character(0), early = FALSE, decisions = list())))
    }
    key <- key_of(remaining)
    hit <- memo[[key]]
    if (!is.null(hit)) return(hit)

    node <- remaining[[1]]
    rest <- remaining[-1]
    type <- node$Type %||% NA_character_

    res <- if (type %in% c("Standard", "Block")) {
      id <- node$ID %||% NA_character_
      lapply(outcomes(rest), function(o) { o$blocks <- c(id, o$blocks); o })
    } else if (type == "EmbeddedData") {
      outcomes(rest)
    } else if (type == "EndSurvey") {
      list(list(blocks = character(0), early = length(rest) > 0L, decisions = list()))
    } else if (type == "Branch") {
      fid <- node$FlowID %||% "branch"
      taken <- annotate(outcomes(c(node$Flow %||% list(), rest)), fid, TRUE)
      not   <- annotate(outcomes(rest), fid, FALSE)
      dedupe(c(taken, not))
    } else if (type == "Group") {
      outcomes(c(node$Flow %||% list(), rest))
    } else if (type == "BlockRandomizer") {
      cli::cli_warn("BlockRandomizer encountered; treating all sub-blocks as shown in order (not enumerating subsets).")
      outcomes(c(node$Flow %||% list(), rest))
    } else {
      cli::cli_warn("Unhandled flow node type {.val {type}}; skipping.")
      outcomes(rest)
    }

    res <- dedupe(res)
    if (length(res) > max_paths) {
      cli::cli_abort(c(
        "This survey's path space is too large to enumerate.",
        i = "More than {max_paths} distinct paths; the flow has {count_branches(nodes)} branches.",
        i = "Raise {.arg max_paths} or treat this as a diagnostic finding (intractable routing)."
      ))
    }
    memo[[key]] <- res
    res
  }

  paths <- dedupe(outcomes(nodes))

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
