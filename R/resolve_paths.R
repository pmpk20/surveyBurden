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
#' @export
resolve_paths <- function(qsf, max_paths = 10000L, catalogue = NULL, blocks = NULL) {
  flow <- resolve_flow(qsf, max_paths = max_paths)
  if (is.null(catalogue)) catalogue <- parse_qsf(qsf)
  if (is.null(blocks))    blocks    <- resolve_live_blocks(qsf)
  block_q <- stats::setNames(blocks$question_ids, blocks$block_id)

  cond_ids <- catalogue$question_id[catalogue$has_display_logic]

  parts <- lapply(flow$block_ids, function(bids) {
    path_qids <- unlist(block_q[bids], use.names = FALSE)
    sub <- catalogue[catalogue$question_id %in% path_qids, ]
    r <- classify_reachability(sub, path_qids)
    triggers <- unique(unlist(sub$display_logic_refs[sub$question_id %in% r$maybe]))
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
#' @export
classify_reachability <- function(catalogue, path_qids) {
  always <- character(0)
  maybe <- character(0)
  unreachable <- character(0)

  for (i in seq_len(nrow(catalogue))) {
    qid  <- catalogue$question_id[i]
    if (!isTRUE(catalogue$has_display_logic[i])) {
      always <- c(always, qid)
      next
    }
    refs <- catalogue$display_logic_refs[[i]]
    if (length(refs) == 0 || all(refs %in% path_qids)) {
      maybe <- c(maybe, qid)
    } else {
      unreachable <- c(unreachable, qid)
    }
  }
  list(always = always, maybe = maybe, unreachable = unreachable)
}

#' Structural summary of an instrument
#'
#' @param qsf A `qsf_raw` object from [read_qsf()].
#' @param blocks Optional precomputed [resolve_live_blocks()] result for this
#'   `qsf` (internal reuse; `NULL` computes it here).
#' @return A list: `survey_name`, `n_questions`, `n_blocks`, `n_branches`,
#'   `n_randomisers`, `n_loop_blocks`, `n_end_points`.
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
