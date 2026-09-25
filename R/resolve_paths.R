#' Resolve respondent paths, flow *and* display logic
#'
#' Combines [resolve_flow()] (block-level routing) with a within-block
#' display-logic reachability analysis. For each flow path it partitions the
#' questions into those always shown, those that *may* be shown (a display-logic
#' condition we cannot evaluate ex ante), and those that can never be shown on
#' that path (the condition's trigger question is not on the path).
#'
#' Interior enumeration of the display-logic state space is **not** performed:
#' a large instrument can carry dozens of root display-logic gates with
#' choice-level mutual exclusivity, which needs a constraint solver. The honest
#' output is the structural band per path (floor = always, ceiling = always +
#' maybe); see [path_burden()].
#'
#' @param qsf A `qsf_raw` object from [read_qsf()].
#' @param max_paths Passed to [resolve_flow()].
#' @param catalogue,blocks Optional precomputed [parse_qsf()] and
#'   [resolve_live_blocks()] results for this `qsf`. Internal: lets
#'   [burden_report()] parse and resolve the instrument once and reuse it. When
#'   `NULL` (default) they are computed here, so the public behaviour is
#'   unchanged.
#'
#' @return A [tibble][tibble::tibble], one row per flow path, with the
#'   [resolve_flow()] columns plus:
#'   \describe{
#'     \item{q_always}{List column: question ids shown on every visit to this path.}
#'     \item{q_maybe}{List column: question ids gated by an unresolved condition.}
#'     \item{n_gates}{Distinct root trigger questions active on this path.}
#'   }
#'
#' @examples
#' qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
#'                          package = "surveyBurden")
#' paths <- resolve_paths(read_qsf(qsf_path))
#' paths[, c("path_id", "terminates_early", "n_gates")]
#'
#' @export
resolve_paths <- function(qsf, max_paths = 10000L, catalogue = NULL, blocks = NULL) {
  flow <- resolve_flow(qsf, max_paths = max_paths)
  if (is.null(catalogue)) catalogue <- parse_qsf(qsf)
  if (is.null(blocks))    blocks    <- resolve_live_blocks(qsf)
  block_q <- stats::setNames(blocks$question_ids, blocks$block_id)

  cond_ids <- catalogue$question_id[catalogue$has_display_logic]

  # Pull the columns out once: subsetting the tibble per path dominated
  # runtime on surveys with tens of thousands of paths.
  cq    <- catalogue$question_id
  c_dl  <- catalogue$has_display_logic
  c_ref <- catalogue$display_logic_refs

  parts <- lapply(flow$block_ids, function(bids) {
    path_qids <- unlist(block_q[bids], use.names = FALSE)
    on <- cq %in% path_qids
    r <- reachability_split(cq[on], c_dl[on], c_ref[on], path_qids)
    triggers <- unique(unlist(c_ref[on][cq[on] %in% r$maybe]))
    root_gates <- setdiff(triggers, cond_ids)
    list(q_always = r$always, q_maybe = r$maybe, n_gates = length(root_gates))
  })

  flow$q_always <- lapply(parts, `[[`, "q_always")
  flow$q_maybe  <- lapply(parts, `[[`, "q_maybe")
  flow$n_gates  <- vapply(parts, `[[`, integer(1), "n_gates")
  flow
}

#' Partition a set of catalogue rows into always / maybe / unreachable
#'
#' @param catalogue Catalogue rows (needs `question_id`, `has_display_logic`,
#'   `display_logic_refs`).
#' @param path_qids Character vector of every question id on the path.
#'
#' @return A list with character vectors `always`, `maybe`, `unreachable`.
#'
#' @examples
#' qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
#'                          package = "surveyBurden")
#' catalogue <- parse_qsf(qsf_path)
#' reach <- classify_reachability(catalogue, catalogue$question_id)
#' lengths(reach)
#'
#' @export
classify_reachability <- function(catalogue, path_qids) {
  reachability_split(catalogue$question_id, catalogue$has_display_logic,
                     catalogue$display_logic_refs, path_qids)
}

#' Vectorised core of [classify_reachability()], on bare columns so
#' [resolve_paths()] can call it per path without subsetting a tibble.
#' No display logic (or `NA`) -> always; every referenced question on the path
#' (or no question reference) -> maybe; otherwise unreachable. Each output
#' keeps the input order.
#' @noRd
reachability_split <- function(qids, has_dl, refs, path_qids) {
  qids <- as.character(qids)
  dl  <- has_dl %in% TRUE
  idx <- which(dl)
  ok  <- vapply(refs[idx], function(r) length(r) == 0L || all(r %in% path_qids),
                logical(1))
  list(always = qids[!dl], maybe = qids[idx[ok]], unreachable = qids[idx[!ok]])
}

#' Structural summary of an instrument
#'
#' @param qsf A `qsf_raw` object from [read_qsf()].
#' @param blocks Optional precomputed [resolve_live_blocks()] result for this
#'   `qsf` (internal reuse; `NULL` computes it here).
#' @return A list: `survey_name`, `n_questions`, `n_blocks`, `n_branches`,
#'   `n_randomisers`, `n_loop_blocks`, `n_end_points`.
#'
#' @examples
#' qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
#'                          package = "surveyBurden")
#' instrument_summary(read_qsf(qsf_path))
#'
#' @export
instrument_summary <- function(qsf, blocks = NULL) {
  if (is.null(blocks)) blocks <- resolve_live_blocks(qsf)
  nodes  <- qsf_flow(qsf)$Flow

  counts <- c(Branch = 0L, BlockRandomizer = 0L, EndSurvey = 0L)
  flow_walk(nodes, function(node) {
    t <- node$Type %||% ""
    if (t %in% names(counts)) counts[[t]] <<- counts[[t]] + 1L
  })

  list(
    survey_name   = qsf$SurveyEntry$SurveyName %||% NA_character_,
    n_questions   = sum(lengths(blocks$question_ids)),
    n_blocks      = nrow(blocks),
    n_branches    = counts[["Branch"]],
    n_randomisers = counts[["BlockRandomizer"]],
    n_loop_blocks = sum(blocks$in_loop),
    n_end_points  = counts[["EndSurvey"]]
  )
}
