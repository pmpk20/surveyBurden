#' Where the burden calculation is exact, and where it rests on assumptions
#'
#' `burden_report()` propagates an established item score through a survey's
#' flow and display logic. Some of that propagation is exact (a fixed block
#' sequence, a loop with an explicit cap); some rests on documented assumptions
#' (the gate-independence approximation for large display-logic components, the
#' independence of separate coupling components). This function reports the
#' split so a reader can see which parts of the output to trust fully and which
#' to read as assumption-dependent.
#'
#' @param qsf A path to a `.qsf`, or a `qsf_raw` object from [read_qsf()].
#' @param weights A [gfs_weights()] list.
#' @param max_paths Passed to [resolve_paths()].
#' @param paths,scored,blocks,parsed_dl Optional precomputed [resolve_paths()],
#'   [score_burden()], [resolve_live_blocks()] and parsed display-logic results
#'   for this `qsf` (internal reuse by [burden_report()]; `NULL` computes them
#'   here, leaving the public behaviour unchanged).
#'
#' @return An object of class `calculation_certainty` (list):
#'   \describe{
#'     \item{paths}{`n_full`, `n_exact` (no unresolved display-logic conditions),
#'       `n_with_unresolved`, and a `per_path` tibble.}
#'     \item{branches}{One row per flow `Branch`, with the trigger variable(s).
#'       Both outcomes of every branch are always enumerated, so a branch is not
#'       an approximation -- but which outcome a given respondent takes is
#'       unknown ex ante.}
#'     \item{display_logic}{`n_conditional` questions gated by an unresolved
#'       condition on some full path; `n_exact` scored by exact joint
#'       enumeration of their gate states; `n_approx` scored with the
#'       primary-gate approximation; component counts; and
#'       `cross_component_independence` (`TRUE` when >1 coupling component is
#'       convolved as independent).}
#'     \item{loops}{`n_known` loop blocks with an explicit iteration cap,
#'       `n_unknown` with a dynamic/unknown bound, and a `bounds` tibble.}
#'     \item{scores}{Counts of `score_flag`: `auto` (confident structural
#'       mapping), `inferred` (mapping needs an assumption), `manual`,
#'       `unknown`.}
#'   }
#'
#' @examples
#' \dontrun{
#' calculation_certainty("survey.qsf")
#' }
#' @export
calculation_certainty <- function(qsf, weights = gfs_weights(), max_paths = 10000L,
                                  paths = NULL, scored = NULL, blocks = NULL,
                                  parsed_dl = NULL) {
  qsf    <- if (inherits(qsf, "qsf_raw")) qsf else read_qsf(qsf)
  if (is.null(paths))  paths  <- resolve_paths(qsf, max_paths = max_paths)
  if (is.null(scored)) scored <- score_burden(parse_qsf(qsf), weights = weights)
  if (is.null(blocks)) blocks <- resolve_live_blocks(qsf)
  full   <- paths[!paths$terminates_early, ]

  # --- paths: exact vs carrying an unresolved display-logic condition ---
  n_maybe <- vapply(full$q_maybe, length, integer(1))
  paths_cert <- list(
    n_full            = nrow(full),
    n_exact           = sum(n_maybe == 0L),
    n_with_unresolved = sum(n_maybe > 0L),
    per_path          = tibble::tibble(
      path_id = full$path_id, n_maybe = n_maybe, n_gates = full$n_gates
    )
  )

  # --- branches: trigger variable(s); both outcomes always enumerated ---
  br <- list()
  flow_walk(qsf_flow(qsf)$Flow, function(n) {
    if (identical(n$Type, "Branch")) {
      v <- tryCatch(parse_display_logic(n$BranchLogic)$vars,
                    error = function(e) character(0))
      br[[length(br) + 1L]] <<- list(
        flow_id = n$FlowID %||% NA_character_,
        trigger = if (length(v)) paste(unique(v), collapse = " / ") else "(unparsed)"
      )
    }
  })
  branch_tbl <- tibble::tibble(
    flow_id = vapply(br, `[[`, character(1), "flow_id"),
    trigger = vapply(br, `[[`, character(1), "trigger")
  )

  # --- display logic: exact enumeration vs primary-gate approximation ---
  dl_cert <- dl_certainty(qsf, scored, full, parsed_dl = parsed_dl)

  # --- loops ---
  lb  <- blocks[blocks$in_loop & !is.na(blocks$loop_max), ]
  lbu <- blocks[blocks$in_loop & is.na(blocks$loop_max), ]
  loops_cert <- list(
    n_known   = nrow(lb),
    n_unknown = nrow(lbu),
    bounds    = tibble::tibble(block_id = lb$block_id,
                               block_name = lb$block_name,
                               max_iter = lb$loop_max)
  )

  # --- item scores ---
  sf <- factor(scored$score_flag, levels = c("auto", "inferred", "manual", "unknown"))
  scores_cert <- as.list(table(sf))
  scores_cert <- lapply(scores_cert, as.integer)

  structure(list(
    survey_name   = qsf$SurveyEntry$SurveyName %||% NA_character_,
    paths         = paths_cert,
    branches      = branch_tbl,
    display_logic = dl_cert,
    loops         = loops_cert,
    scores        = scores_cert
  ), class = "calculation_certainty")
}

#' Exact-vs-approximation split of the display-logic gates, matching the
#' component logic in [path_burden_profile()].
#' @noRd
dl_certainty <- function(qsf, scored, full, exact_cap = EXACT_CAP, parsed_dl = NULL) {
  parsed <- parsed_dl %||% parse_all_display_logic(qsf, scored)
  stype <- stats::setNames(scored$std_type, scored$question_id)

  cond <- unique(unlist(full$q_maybe))
  cond <- cond[cond %in% names(parsed)]

  exact_q <- character(0); approx_q <- character(0)
  n_comp <- 0L; n_exact_comp <- 0L; n_approx_comp <- 0L
  if (length(cond)) {
    for (grp in connected_components(cond, parsed)) {
      n_comp <- n_comp + 1L
      gvars  <- unique(unlist(lapply(grp, function(q) parsed[[q]]$vars)))
      states <- lapply(gvars, function(v) gate_states(v, grp, parsed, stype))
      total  <- prod(vapply(states, length, numeric(1)))
      if (length(gvars) <= 1 || total <= exact_cap) {
        exact_q <- c(exact_q, grp); n_exact_comp <- n_exact_comp + 1L
      } else {
        approx_q <- c(approx_q, grp); n_approx_comp <- n_approx_comp + 1L
      }
    }
  }

  list(
    n_conditional               = length(cond),
    n_exact                     = length(exact_q),
    n_approx                    = length(approx_q),
    approx_questions            = approx_q,
    n_components                = n_comp,
    n_exact_components          = n_exact_comp,
    n_approx_components         = n_approx_comp,
    cross_component_independence = n_comp > 1L
  )
}

#' @export
print.calculation_certainty <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

#' @export
format.calculation_certainty <- function(x, ...) {
  cli::cli_fmt(print_calculation_certainty_body(x), collapse = FALSE)
}

print_calculation_certainty_body <- function(x) {
  p <- x$paths; d <- x$display_logic; l <- x$loops; s <- x$scores

  cli::cli_h1("Calculation certainty: {x$survey_name}")

  cli::cli_h2("Paths")
  cli::cli_text("{p$n_exact} of {p$n_full} complete paths resolve exactly (no unresolved display-logic condition); {p$n_with_unresolved} carry at least one.")
  if (nrow(x$branches) > 0) {
    cli::cli_text("{nrow(x$branches)} flow branches; both outcomes of each are enumerated, but which one a given respondent takes is unknown ex ante:")
    for (i in seq_len(nrow(x$branches))) {
      cli::cli_text("  {x$branches$flow_id[i]}: trigger {x$branches$trigger[i]}")
    }
  }

  cli::cli_h2("Display logic")
  cli::cli_text("{d$n_conditional} conditional questions on some path: {d$n_exact} scored by exact joint enumeration, {d$n_approx} with the primary-gate approximation.")
  cli::cli_text("{d$n_components} coupling components ({d$n_exact_components} exact, {d$n_approx_components} approximated).")
  if (isTRUE(d$cross_component_independence)) {
    cli::cli_text("Separate components are convolved as independent (assumption).")
  }

  cli::cli_h2("Loops")
  cli::cli_text("{l$n_known} loop blocks with an explicit iteration cap; {l$n_unknown} with a dynamic/unknown bound.")
  for (i in seq_len(nrow(l$bounds))) {
    cli::cli_text("  {l$bounds$block_name[i]}: 0-{l$bounds$max_iter[i]} iterations")
  }

  cli::cli_h2("Item scores")
  cli::cli_text("{s$auto} scored with full confidence (auto); {s$inferred} by structural inference (inferred); {s$manual} need manual verification; {s$unknown} unmapped.")

  invisible(x)
}
