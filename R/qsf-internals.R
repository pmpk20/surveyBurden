# Internal helpers shared across the parser. Not exported.

`%||%` <- function(a, b) if (is.null(a)) b else a

# Largest joint gate-state count a display-logic coupling component is
# enumerated exactly for; above this it falls back to the primary-gate
# approximation. Referenced by both component_dist() (which produces the burden
# numbers) and dl_certainty() (which reports the exact/approx split), so the two
# cannot silently disagree.
EXACT_CAP <- 10000L

validate_condition_states <- function(x) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) ||
      x < 1 || x != floor(x)) {
    stop("max_condition_states must be a single positive finite whole number.", call. = FALSE)
  }
  invisible(x)
}

#' Return the `Payload` of every `SurveyElements` entry with a given `Element` tag
#' @noRd
qsf_elements <- function(qsf, type) {
  keep <- vapply(
    qsf$SurveyElements,
    function(e) identical(e$Element, type),
    logical(1)
  )
  lapply(qsf$SurveyElements[keep], `[[`, "Payload")
}

#' The single block-definitions payload (a list of block objects)
#' @noRd
qsf_block_defs <- function(qsf) {
  bl <- qsf_elements(qsf, "BL")
  if (length(bl) != 1L) {
    cli::cli_abort("Expected exactly one {.field BL} element, found {length(bl)}.")
  }
  payload <- bl[[1]]
  # .qsf gives an unnamed array; the API gives an object keyed by block id
  if (!is.null(names(payload)) && any(grepl("^BL_", names(payload)))) {
    payload <- unname(payload)
  }
  payload
}

#' The survey-flow payload (`$Flow` is the ordered list of top-level flow nodes)
#'
#' Flow nodes after the first top-level `EndSurvey` are dropped: an
#' unconditional end of survey stops every respondent, so nothing after it can
#' be shown. Edited surveys sometimes keep such leftover blocks, which would
#' otherwise make every route look as if it ended early.
#' @noRd
qsf_flow <- function(qsf) {
  fl <- qsf_elements(qsf, "FL")
  if (length(fl) != 1L) {
    cli::cli_abort("Expected exactly one {.field FL} element, found {length(fl)}.")
  }
  fl <- fl[[1]]
  cut <- flow_end_index(fl[["Flow"]])
  if (!is.na(cut)) fl[["Flow"]] <- fl[["Flow"]][seq_len(cut)]
  fl
}

#' Position of the first top-level `EndSurvey` that has flow nodes after it,
#' or `NA` when there is none.
#' @noRd
flow_end_index <- function(nodes) {
  if (!is.list(nodes) || !length(nodes)) return(NA_integer_)
  types <- vapply(nodes, function(n) if (is.list(n)) n$Type %||% "" else "", character(1))
  k <- which(types == "EndSurvey")
  if (!length(k) || k[1] == length(nodes)) return(NA_integer_)
  k[1]
}

#' Block ids that sit after the first top-level `EndSurvey` and are never
#' shown (empty when there are none).
#' @noRd
blocks_after_end <- function(qsf) {
  fl <- qsf_elements(qsf, "FL")
  if (length(fl) != 1L) return(character(0))
  nodes <- fl[[1]][["Flow"]]
  cut <- flow_end_index(nodes)
  if (is.na(cut)) return(character(0))
  ids <- character(0)
  flow_walk(nodes[-seq_len(cut)], function(n) {
    if (n$Type %in% c("Standard", "Block")) ids <<- c(ids, n$ID %||% NA_character_)
  })
  unique(ids[!is.na(ids)])
}

#' Walk the flow tree depth-first, calling `fn(node)` on every node that has a
#' `Type`. Recurses into any `$Flow` child list.
#' @noRd
flow_walk <- function(node, fn) {
  if (!is.list(node)) return(invisible())
  items <- if (!is.null(node$Type)) list(node) else node
  for (it in items) {
    if (!is.list(it) || is.null(it$Type)) next
    fn(it)
    if (!is.null(it[["Flow"]])) flow_walk(it[["Flow"]], fn)
  }
  invisible()
}
