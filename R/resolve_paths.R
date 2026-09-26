#' Resolve the survey's paths, flow *and* display logic
#'
#' Combines [resolve_flow()] (block-level routing) with a within-block
#' display-logic reachability analysis. For each flow path it partitions the
#' questions into those always shown, those that *may* be shown (a display-logic
#' condition we cannot evaluate ex ante), and those whose display logic is
#' shown to be false on that path because of the questions the path does not
#' show (see [classify_reachability()] for the rule).
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
  parsed   <- parse_all_display_logic(qsf, catalogue)

  # Pull the columns out once: subsetting the tibble per path dominated
  # runtime on surveys with tens of thousands of paths.
  cq    <- catalogue$question_id
  c_dl  <- catalogue$has_display_logic
  c_ref <- catalogue$display_logic_refs

  parts <- lapply(flow$block_ids, function(bids) {
    path_qids <- unlist(block_q[bids], use.names = FALSE)
    on <- cq %in% path_qids
    r <- reachability_split(cq[on], c_dl[on], c_ref[on], path_qids, parsed)
    # trigger questions a respondent can actually answer on this path
    triggers <- intersect(unique(unlist(c_ref[on][cq[on] %in% r$maybe])),
                          c(r$always, r$maybe))
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
#' A question with no display logic is `always` shown. A question with display
#' logic is `unreachable` only when its logic is shown to be false on this
#' path: the questions it refers to that are not on the path (or are
#' themselves unreachable) are unanswered and not displayed, so their
#' conditions have fixed values, and if the logic is then false whatever the
#' on-path answers are, the question can never be shown. Otherwise it is
#' `maybe`. So a question whose logic is "Q9 is selected OR Q2 is selected"
#' stays `maybe` when only Q9 is off the path, and "Q9 is not selected" is
#' `maybe` (in fact always true) when Q9 is off the path.
#'
#' Unknown conditions are treated as independent, so the rule can leave a
#' question as `maybe` that could be ruled out, but never marks a question
#' `unreachable` wrongly (within the conditions it understands; embedded-data
#' and other non-question conditions are always treated as unknown).
#'
#' @param catalogue Catalogue rows (needs `question_id`, `has_display_logic`,
#'   `display_logic_refs`).
#' @param path_qids Character vector of every question id on the path.
#' @param display_logic Optional named list, by question id, of each
#'   question's Qualtrics `DisplayLogic` tree (a question payload's
#'   `$DisplayLogic`). Without it the logic cannot be evaluated, so no
#'   question is classed `unreachable`: every question with display logic is
#'   `maybe`. [resolve_paths()] supplies it from the survey.
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
classify_reachability <- function(catalogue, path_qids, display_logic = NULL) {
  parsed <- lapply(display_logic, function(dl) {
    if (is.list(dl) && is.function(dl$possible)) dl else parse_display_logic(dl)
  })
  reachability_split(catalogue$question_id, catalogue$has_display_logic,
                     catalogue$display_logic_refs, path_qids, parsed)
}

#' Vectorised core of [classify_reachability()], on bare columns so
#' [resolve_paths()] can call it per path without subsetting a tibble.
#' `parsed` is a named list of [parse_display_logic()] results. A question
#' with display logic is unreachable only when `$possible()` proves its logic
#' false given the questions that are off the path or already ruled out;
#' ruling one out can rule out questions that depend on it, so this repeats
#' until nothing changes. Each output keeps the input order.
#' @noRd
reachability_split <- function(qids, has_dl, refs, path_qids, parsed = NULL) {
  qids <- as.character(qids)
  dl  <- has_dl %in% TRUE
  idx <- which(dl)

  # only a question referring to something off the path can be ruled out
  refs_off <- function(r, gone) length(r) > 0L && !all(r %in% path_qids & !r %in% gone)
  ruled_out <- character(0)
  cand <- idx[vapply(refs[idx], refs_off, logical(1), gone = ruled_out)]
  while (length(cand)) {
    new <- character(0)
    for (i in cand) {
      p <- parsed[[qids[i]]]
      if (is.null(p)) next                       # logic unknown: cannot prove
      off <- union(setdiff(p$vars, path_qids), intersect(p$vars, ruled_out))
      if (!p$possible(off)) new <- c(new, qids[i])
    }
    new <- setdiff(new, ruled_out)
    if (!length(new)) break
    ruled_out <- c(ruled_out, new)
    # re-check questions that depend on a newly ruled-out question
    cand <- idx[!qids[idx] %in% ruled_out &
                vapply(refs[idx], function(r) any(r %in% new), logical(1))]
  }

  gone <- qids %in% ruled_out
  list(always = qids[!dl], maybe = qids[dl & !gone], unreachable = qids[dl & gone])
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
  nodes  <- qsf_flow(qsf)[["Flow"]]

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
