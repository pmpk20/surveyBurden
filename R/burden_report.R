#' Ex-ante instrument burden report
#'
#' The user-facing entry point. Parses a Qualtrics `.qsf`, resolves its flow and
#' display logic, scores every question with the GfS / Axhausen scheme, and
#' summarises the burden across the instrument's structural path space.
#'
#' @param x A path to a `.qsf` file, or a `qsf_raw` object from [read_qsf()].
#' @param weights A [gfs_weights()] list.
#' @param profile If `TRUE` (default), enumerate the display-logic structural
#'   burden profile ([path_burden_profile()]) to get the *achievable* min/median/
#'   max burden for this survey -- a few seconds of extra work. `FALSE` skips
#'   that and falls back to a much faster but naive range (see Details): min/max
#'   only, no median, and the numbers can understate the true minimum.
#' @param routes Optional respondent data frame (see [respondent_burden()]).
#'   When supplied, the report adds a population-weighted burden summary: each
#'   route is weighted by how often respondents actually take it, so unlike the
#'   structural profile this is a real average over respondents.
#' @param rare_threshold GfS points above which Heimgartner & Axhausen (2024)
#'   found surveys to be rare (their sample: median 399, n = 79 waves). Used for
#'   the "rare burden" warning and to scale the `index` column of `$burden` to
#'   0-1.
#' @param stem_warning_threshold Question stems longer than this many words are
#'   flagged in the readability diagnostics (default 40). Diagnostic only --
#'   this does **not** change any GfS score.
#' @param label_warning_threshold For matrix/grid questions, response-option or
#'   row labels longer than this many words are flagged (default 10). Diagnostic
#'   only.
#' @param certainty If `TRUE` (default), attach and print the
#'   [calculation_certainty()] breakdown. `FALSE` skips it (a little faster).
#' @param quiet If `FALSE` (default), report progress through the pipeline
#'   stages with [cli::cli_progress_step()]. `TRUE` silences it.
#'
#' @details
#' **Why two ranges exist.** [path_burden()] (the fast, naive check) scores each
#' flow path by assuming every optional (display-logic-gated) question can be
#' independently hidden for the minimum, or independently shown for the maximum.
#' That assumption is not always achievable: some questions are gated by
#' conditions that are satisfied by default (e.g. "shown unless a specific answer
#' was picked"), so they cannot actually be hidden regardless of what else the
#' respondent answers. [path_burden_profile()] enumerates the real display-logic
#' combinations and finds the burden values that are genuinely reachable, which
#' is why its minimum is usually *higher* than the naive floor. **This report
#' uses the profile's range as the one range shown, whenever `profile = TRUE`.**
#'
#' **Path-space cap.** The structural path space is enumerated up to
#' `max_paths` (10000, set inside [resolve_flow()]). A flow that would produce
#' more raises an error rather than a partial answer; a survey that hits it has
#' genuinely intractable routing. Block randomisers are treated as "all
#' sub-blocks shown, in survey order" -- the randomised subsets are not
#' enumerated.
#'
#' @return An object of class `burden_report`: a list of tibbles under stable
#'   names. Print it for the formatted summary, or read its components:
#'   \describe{
#'     \item{instrument}{One-row tibble of structural counts: `survey_name`,
#'       `n_questions`, `n_blocks`, `n_branches`, `n_randomisers`,
#'       `n_loop_blocks`, `n_end_points`, `n_paths`, `n_complete_paths`,
#'       `n_screenout_paths`.}
#'     \item{burden}{Five-row tibble, one row per statistic (`min`, `p25`,
#'       `median`, `p75`, `max`), with `points`, `minutes` (points per minute
#'       from [gfs_weights()]) and `index` (`points / rare_threshold`).
#'       `attr(, "basis")` is `"structural"` when `profile = TRUE`, else
#'       `"naive"` and only `min` / `max` are populated.}
#'     \item{blocks}{One row per block, in survey order: `block_id`,
#'       `block_name`, `flow_order`, `n_questions`, `gfs_points` and `share`
#'       (share of all-question points).}
#'     \item{items}{The full [score_burden()] table, every live question with
#'       its `gfs_points`, `score_flag` and `score_basis`.}
#'     \item{paths}{One row per structural path: `path_id`, `status` (factor
#'       `complete` / `screen_out`), `n_blocks`, `n_questions_floor`,
#'       `n_questions_ceiling`, `burden_floor`, `burden_ceiling`, `n_gates`, and
#'       `burden_min` / `burden_median` / `burden_max` (`NA` when
#'       `profile = FALSE`).}
#'     \item{readability}{Diagnostic, not part of the GfS score: `stem_threshold`,
#'       `label_threshold`, and the tibbles `long_stems`, `long_labels` and
#'       `long_grids`.}
#'     \item{certainty}{[calculation_certainty()] output, or `NULL` when
#'       `certainty = FALSE`.}
#'     \item{warnings}{Character vector of QC flags, in plain language.}
#'     \item{population}{Present only when `routes` is supplied: a tibble the
#'       same shape as `burden`, weighted by observed respondent routes.}
#'   }
#'   Scalars are attributes: `points_per_minute`, `rare_threshold`, `benchmark`
#'   (`list(median_points, n_waves)`) and `profile_used`.
#'
#' @param words_per_line Optional override for the descriptive-text "lines"
#'   conversion (default 12, from [gfs_weights()]). This is a pragmatic
#'   conversion heuristic -- GfS scores instruction text in rendered lines, and
#'   a QSF has words, not a rendered width -- not an empirically calibrated
#'   constant. Set it to your survey theme's typical line length if you have
#'   one.
#'
#' @examples
#' \dontrun{
#' br <- burden_report("survey.qsf")
#' br                       # formatted summary
#' summary(br)              # short headline
#' br$burden                # the min/median/max table
#' br$items[order(-br$items$gfs_points), ]   # questions by burden
#' br$paths
#' }
#' @export
burden_report <- function(x, weights = gfs_weights(), profile = TRUE,
                          routes = NULL, rare_threshold = 1500,
                          stem_warning_threshold = 40L,
                          label_warning_threshold = 10L,
                          words_per_line = NULL,
                          certainty = TRUE,
                          quiet = FALSE) {
  step <- if (isTRUE(quiet)) function(...) invisible() else cli::cli_progress_step

  step("Reading survey")
  qsf <- if (inherits(x, "qsf_raw")) x else read_qsf(x)
  if (!is.null(words_per_line)) weights$words_per_line <- words_per_line

  step("Scoring questions and resolving paths")
  # Parse / score / resolve the instrument once here and thread the results
  # through the pipeline; every function below accepts them precomputed and
  # falls back to computing its own when called directly.
  catalogue <- parse_qsf(qsf)
  scored    <- score_burden(catalogue, weights = weights)
  blocks    <- resolve_live_blocks(qsf)
  paths     <- resolve_paths(qsf, catalogue = catalogue, blocks = blocks)
  isum      <- instrument_summary(qsf, blocks = blocks)
  pb        <- path_burden(qsf, weights = weights, paths = paths, scored = scored)
  ppm    <- weights$points_per_minute
  full   <- pb[!pb$terminates_early, ]
  no_complete <- nrow(full) == 0L

  # parse each question's display-logic tree once; the engine and the certainty
  # breakdown both need it.
  need_engine <- !no_complete && (isTRUE(profile) || !is.null(routes))
  parsed_dl <- if (need_engine || isTRUE(certainty))
    parse_all_display_logic(qsf, scored) else NULL

  # the display-logic engine is the expensive step; build it once if either the
  # structural profile or a routes summary will need it.
  engine <- if (need_engine)
    burden_engine(qsf, weights = weights, paths = paths, scored = scored,
                  blocks = blocks, parsed_dl = parsed_dl) else NULL

  step("Checking calculation certainty")
  cert   <- if (isTRUE(certainty))
    calculation_certainty(qsf, weights = weights, paths = paths, scored = scored,
                          blocks = blocks, parsed_dl = parsed_dl) else NULL

  # ---- $instrument -------------------------------------------------------
  instrument <- tibble::tibble(
    survey_name       = isum$survey_name,
    n_questions       = as.integer(isum$n_questions),
    n_blocks          = as.integer(isum$n_blocks),
    n_branches        = as.integer(isum$n_branches),
    n_randomisers     = as.integer(isum$n_randomisers),
    n_loop_blocks     = as.integer(isum$n_loop_blocks),
    n_end_points      = as.integer(isum$n_end_points),
    n_paths           = nrow(pb),
    n_complete_paths  = nrow(full),
    n_screenout_paths = sum(pb$terminates_early)
  )

  # ---- $blocks (every block, in survey order) --------------------------
  pts_by_block <- tapply(scored$gfs_points, scored$block_id, sum, na.rm = TRUE)
  gp <- as.numeric(pts_by_block[blocks$block_id])
  gp[is.na(gp)] <- 0
  blocks_tbl <- tibble::tibble(
    block_id    = blocks$block_id,
    block_name  = blocks$block_name,
    flow_order  = blocks$flow_order,
    n_questions = lengths(blocks$question_ids),
    gfs_points  = gp,
    share       = if (sum(gp) > 0) gp / sum(gp) else gp
  )
  blocks_tbl <- blocks_tbl[order(blocks_tbl$flow_order), ]

  # ---- $paths ----------------------------------------------------------
  status <- factor(ifelse(pb$terminates_early, "screen_out", "complete"),
                   levels = c("complete", "screen_out"))
  paths_tbl <- tibble::tibble(
    path_id             = pb$path_id,
    status              = status,
    n_blocks            = pb$n_blocks,
    n_questions_floor   = pb$n_q_floor,
    n_questions_ceiling = pb$n_q_ceiling,
    burden_floor        = pb$gfs_floor,
    burden_ceiling      = pb$gfs_ceiling,
    n_gates             = pb$n_gates,
    burden_min          = NA_real_,
    burden_median       = NA_real_,
    burden_max          = NA_real_
  )

  # ---- $burden --------------------------------------------------------
  probs <- c("min", "p25", "median", "p75", "max")
  if (no_complete) {
    # every structural path screens out: there is no completing path to
    # summarise a burden spread over. Report NA and flag it (below); the
    # per-path burdens are still in $paths.
    pts        <- rep(NA_real_, 5L)
    basis      <- "none"
    gate_range <- c(NA_integer_, NA_integer_)
  } else if (isTRUE(profile)) {
    step("Enumerating display-logic combinations")
    pbp   <- path_burden_profile(qsf, weights = weights, engine = engine)
    m     <- match(paths_tbl$path_id, pbp$path_id)
    paths_tbl$burden_min    <- pbp$burden_min[m]
    paths_tbl$burden_median <- pbp$burden_median[m]
    paths_tbl$burden_max    <- pbp$burden_max[m]
    pooled <- do.call(rbind, pbp$profile[!pbp$terminates_early])
    pts <- weighted_quantile(pooled$burden, pooled$weight, c(0, .25, .5, .75, 1))
    basis <- "structural"
    gate_range <- range(full$n_gates)
  } else {
    pts <- c(min(full$gfs_floor), NA, NA, NA, max(full$gfs_ceiling))
    basis <- "naive"
    gate_range <- range(full$n_gates)
  }
  burden_tbl <- tibble::tibble(
    statistic = factor(probs, levels = probs),
    points    = as.numeric(pts),
    minutes   = as.numeric(pts) / ppm,
    index     = as.numeric(pts) / rare_threshold
  )
  attr(burden_tbl, "basis") <- basis

  # ---- $readability --------------------------------------------------
  answerable <- !scored$std_type %in% c("descriptive", "meta", "timing", "captcha")
  ls <- scored[answerable & !is.na(scored$text_words) &
                 scored$text_words > stem_warning_threshold, ]
  ls <- ls[order(-ls$text_words),
           c("question_id", "block_name", "text_words", "question_text")]
  ll <- scored[scored$std_type == "matrix" & !is.na(scored$max_label_words) &
                 scored$max_label_words > label_warning_threshold, ]
  ll <- ll[order(-ll$max_label_words),
           c("question_id", "block_name", "max_label_words", "question_text")]
  lg <- scored[scored$std_type == "matrix" & !is.na(scored$n_rows) & scored$n_rows > 6, ]
  lg <- lg[order(-lg$n_rows),
           c("question_id", "block_name", "n_rows", "question_text")]
  readability <- list(
    stem_threshold  = as.integer(stem_warning_threshold),
    label_threshold = as.integer(label_warning_threshold),
    long_stems  = tibble::as_tibble(ls),
    long_labels = tibble::as_tibble(ll),
    long_grids  = tibble::as_tibble(lg)
  )

  # ---- $warnings ----------------------------------------------------
  warnings <- character(0)
  unmapped <- scored[scored$score_flag == "unknown" | is.na(scored$gfs_points), ]
  if (nrow(unmapped) > 0) {
    n_um <- nrow(unmapped)
    warnings <- c(warnings, sprintf(
      "%d question%s could not be scored (unrecognised Qualtrics type: %s) and contribute%s 0 to every burden figure here -- the reported burden is an UNDER-count for any path that shows %s: %s",
      n_um, if (n_um == 1) "" else "s",
      paste(sort(unique(unmapped$qualtrics_type)), collapse = ", "),
      if (n_um == 1) "s" else "",
      if (n_um == 1) "it" else "them",
      paste(unmapped$question_id, collapse = ", ")))
  }
  if (nrow(ls) > 0) {
    warnings <- c(warnings, sprintf(
      "%d question stem%s exceed%s %d words (reading load, not scored as GfS burden): %s",
      nrow(ls), if (nrow(ls) == 1) "" else "s", if (nrow(ls) == 1) "s" else "",
      stem_warning_threshold, paste(ls$question_id, collapse = ", ")))
  }
  if (nrow(ll) > 0) {
    warnings <- c(warnings, sprintf(
      "%d matrix question%s have a response/row label longer than %d words (reading load, not scored): %s",
      nrow(ll), if (nrow(ll) == 1) "" else "s",
      label_warning_threshold, paste(ll$question_id, collapse = ", ")))
  }
  if (nrow(lg) > 0) {
    warnings <- c(warnings, sprintf(
      "%d matrix/grid question%s ha%s more than 6 rows. Long grids invite satisficing (respondents picking the same answer down the column instead of reading each row): %s",
      nrow(lg), if (nrow(lg) == 1) "" else "s", if (nrow(lg) == 1) "s" else "ve",
      paste(lg$question_id, collapse = ", ")))
  }
  if (no_complete) {
    warnings <- c(warnings, sprintf(
      "This survey has no completing path: all %d structural paths screen out (the survey ends early on every one). No burden spread is reported; the per-path burden for each screen-out path is in `$paths`.",
      nrow(pb)))
  } else if (any(pb$terminates_early)) {
    warnings <- c(warnings, sprintf(
      "%d of %d structural paths are screen-outs (the survey ends early there) rather than complete responses.",
      sum(pb$terminates_early), nrow(pb)))
  }
  if (identical(basis, "naive")) {
    warnings <- c(warnings, sprintf(
      "%d-%d display-logic combinations per full path were not checked (profile = FALSE); the range below is a fast estimate and its minimum may not actually be reachable.",
      gate_range[1], gate_range[2]))
  } else if (identical(basis, "structural")) {
    if (burden_tbl$points[burden_tbl$statistic == "max"] > rare_threshold) {
      warnings <- c(warnings, sprintf(
        "The heaviest reachable burden (%.0f pts) is above %.0f points, the level Heimgartner & Axhausen (2024) found rare among the %d survey waves they scored with the same GfS method (their sample median: 399 pts).",
        burden_tbl$points[burden_tbl$statistic == "max"], rare_threshold, 79L))
    }
    warnings <- c(warnings, paste(
      "The point range above comes from checking every combination of optional",
      "questions this survey's skip logic could show. Each combination is",
      "counted once; we have no data on how likely each one is for a given",
      "respondent, so this is a structural range, not a probability -- it does",
      "NOT mean \"there's a 50% chance a respondent sees the median burden\"."))
  }

  # ---- $population (optional) --------------------------------------
  population <- NULL
  if (!is.null(routes)) {
    pr <- respondent_burden(qsf, routes = routes, weights = weights, engine = engine)
    qp <- stats::quantile(pr$pred_pts, c(0, .25, .5, .75, 1), na.rm = TRUE)
    population <- tibble::tibble(
      statistic = factor(probs, levels = probs),
      points    = as.numeric(qp),
      minutes   = as.numeric(qp) / ppm,
      index     = as.numeric(qp) / rare_threshold
    )
    warnings <- c(warnings, sprintf(
      "The population-weighted numbers use %d respondent routes, so (unlike the structural range) they ARE weighted by how often each route actually occurred.",
      nrow(pr)))
  }

  lead <- c("question_id", "block_id", "block_name", "question_text", "std_type",
            "selector", "n_rows", "n_cols", "n_options", "gfs_points", "est_seconds",
            "score_flag", "score_basis", "text_words", "max_label_words",
            "has_display_logic", "loop_max")
  scored <- scored[, c(intersect(lead, names(scored)), setdiff(names(scored), lead))]

  out <- list(
    instrument  = instrument,
    burden      = burden_tbl,
    blocks      = tibble::as_tibble(blocks_tbl),
    items       = tibble::as_tibble(scored),
    paths       = paths_tbl,
    readability = readability,
    certainty   = cert,
    warnings    = warnings
  )
  if (!is.null(population)) out$population <- population
  attr(out, "points_per_minute") <- ppm
  attr(out, "rare_threshold")    <- rare_threshold
  attr(out, "benchmark")         <- list(median_points = 399, n_waves = 79L)
  attr(out, "profile_used")      <- isTRUE(profile)
  attr(out, "gate_range")        <- gate_range
  class(out) <- "burden_report"
  out
}

#' @export
print.burden_report <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

#' @export
format.burden_report <- function(x, ...) {
  cli::cli_fmt(print_burden_report_body(x), collapse = FALSE)
}

# Right/left-align a character matrix (row 1 = header) into aligned columns
# with a rule under the header. `right` is a logical vector, one per column.
render_table <- function(mat, right = NULL) {
  if (is.null(right)) right <- c(FALSE, rep(TRUE, ncol(mat) - 1L))
  w <- apply(mat, 2L, function(col) max(nchar(col)))
  fmt_row <- function(row) paste(
    vapply(seq_along(row), function(j)
      formatC(row[j], width = if (right[j]) w[j] else -w[j]), character(1)),
    collapse = "  ")
  c(fmt_row(mat[1, ]),
    strrep("-", sum(w) + 2L * (ncol(mat) - 1L)),
    vapply(seq_len(nrow(mat))[-1], function(i) fmt_row(mat[i, ]), character(1)))
}

#' One- or two-line plain-language verdict for a burden report, shared by the
#' full print method and [summary()][summary.burden_report] so the two cannot
#' drift. `burden` is the `$burden` tibble -- its `attr(, "basis")` selects the
#' wording. `population_median` is the population-weighted median burden in
#' points, or `NULL` when no `routes` were supplied.
#' @noRd
burden_verdict_line <- function(burden, ppm, benchmark_median, n_complete,
                                population_median = NULL) {
  basis <- attr(burden, "basis")
  pt    <- function(stat) burden$points[burden$statistic == stat]
  pl    <- if (identical(n_complete, 1L)) "" else "s"

  if (identical(basis, "none")) {
    return("No completing path: every structural path screens out. Per-path burden is in {.code $paths}.")
  }

  mn   <- round(pt("min"));       mx   <- round(pt("max"))
  mn_m <- round(pt("min") / ppm); mx_m <- round(pt("max") / ppm)

  if (identical(basis, "naive")) {
    return(sprintf(
      "Path burden runs %d-%d points (~%d-%d min) across %d completing path%s (naive band; median not computed).",
      mn, mx, mn_m, mx_m, n_complete, pl))
  }

  med   <- round(pt("median"))
  med_m <- round(pt("median") / ppm)
  ratio <- sprintf("%.1f", pt("median") / benchmark_median)
  line1 <- sprintf(
    "Median completing path: %d GfS points, ~%d min - %sx the benchmark median of %d. Path burden ranges %d-%d points (%d-%d min) across %d completing path%s.",
    med, med_m, ratio, round(benchmark_median), mn, mx, mn_m, mx_m, n_complete, pl)

  if (is.null(population_median)) return(line1)
  c(line1, sprintf(
    "Population-weighted median: %d points (~%d min) across the supplied routes.",
    round(population_median), round(population_median / ppm)))
}

print_burden_report_body <- function(x) {
  ins <- x$instrument
  ppm <- attr(x, "points_per_minute")
  rt  <- attr(x, "rare_threshold")
  bm  <- attr(x, "benchmark")
  gr  <- attr(x, "gate_range")
  trunc_txt <- function(s, n) ifelse(nchar(s) > n, paste0(substr(s, 1, n - 3), "..."), s)

  cli::cli_h1("Survey Burden Report: {ins$survey_name}")

  verdict <- burden_verdict_line(
    x$burden, ppm, bm$median_points, ins$n_complete_paths,
    population_median = if (!is.null(x$population))
      x$population$points[x$population$statistic == "median"] else NULL)
  for (ln in verdict) cli::cli_text(ln)

  cli::cli_h2("Instrument")
  cli::cli_verbatim(render_table(rbind(
    c("", ""),
    c("Questions (live)",    ins$n_questions),
    c("Blocks",              ins$n_blocks),
    c("Branch points",       ins$n_branches),
    c("Randomisers",         ins$n_randomisers),
    c("Loop & Merge blocks", ins$n_loop_blocks),
    c("Early-exit points",   ins$n_end_points)
  ))[-c(1, 2)])

  cli::cli_h2("Paths")
  cli::cli_text("Structural paths: {ins$n_paths} ({ins$n_complete_paths} complete, {ins$n_screenout_paths} screen-out)")
  if (ins$n_complete_paths > 0L) {
    cli::cli_text("Display-logic combinations checked: {gr[1]}-{gr[2]} per complete path")
  }

  cli::cli_h2("Burden ({ppm} GfS points ~ 1 minute; index = points / {rt})")
  b <- x$burden
  labs <- c(min = "Minimum", p25 = "25th percentile", median = "Median",
            p75 = "75th percentile", max = "Maximum")
  if (identical(attr(b, "basis"), "none")) {
    cli::cli_text("No completing path: every structural path screens out. Per-path burden is in {.code $paths}.")
  } else {
    if (identical(attr(b, "basis"), "naive")) b <- b[b$statistic %in% c("min", "max"), ]
    cli::cli_verbatim(render_table(rbind(
      c("Statistic", "Points", "~Min", "Index"),
      cbind(labs[as.character(b$statistic)],
            formatC(b$points,  format = "f", digits = 0),
            formatC(b$minutes, format = "f", digits = 0),
            formatC(b$index,   format = "f", digits = 2))
    )))
  }
  cli::cli_text("Benchmark: median {bm$median_points} points across {bm$n_waves} GfS-scored survey waves (Heimgartner & Axhausen 2024).")

  if (!is.null(x$population)) {
    p <- x$population
    cli::cli_h2("Population-weighted burden (from your respondent routes)")
    cli::cli_verbatim(render_table(rbind(
      c("Statistic", "Points", "~Min", "Index"),
      cbind(labs[as.character(p$statistic)],
            formatC(p$points,  format = "f", digits = 0),
            formatC(p$minutes, format = "f", digits = 0),
            formatC(p$index,   format = "f", digits = 2))
    )))
  }

  cli::cli_h2("Burden by block (survey order; share of all-question points)")
  bl <- x$blocks
  bar <- function(s) if (s <= 0) "" else strrep("#", max(1L, round(s * 30)))
  cli::cli_verbatim(vapply(seq_len(nrow(bl)), function(i)
    sprintf("%-24s %3.0f%%  %s", trunc_txt(bl$block_name[i], 24),
            bl$share[i] * 100, bar(bl$share[i])), character(1)))

  cli::cli_h2("Highest-burden questions")
  ti <- utils::head(x$items[order(-x$items$gfs_points), ], 6L)
  dims <- ifelse(!is.na(ti$n_rows), sprintf("%dx%d", ti$n_rows, ti$n_cols),
                 ifelse(!is.na(ti$n_options), sprintf("%d opt", ti$n_options), ""))
  cli::cli_verbatim(vapply(seq_len(nrow(ti)), function(i)
    sprintf("%-8s %4.0f pts  %-8s %s", ti$question_id[i], ti$gfs_points[i],
            dims[i], trunc_txt(ti$question_text[i], 58)), character(1)))

  rd <- x$readability
  cli::cli_h2("Readability diagnostics (reading load; not part of the GfS score)")
  cli::cli_verbatim(render_table(rbind(
    c("", ""),
    c(sprintf("Long stems (> %d words)", rd$stem_threshold),        nrow(rd$long_stems)),
    c(sprintf("Long matrix labels (> %d words)", rd$label_threshold), nrow(rd$long_labels)),
    c("Long grids (> 6 rows)",                                       nrow(rd$long_grids))
  ))[-c(1, 2)])

  ct <- x$certainty
  if (!is.null(ct)) {
    cp <- ct$paths; cd <- ct$display_logic; cl <- ct$loops; cs <- ct$scores
    cli::cli_h2("Calculation certainty")
    cli::cli_text("Paths: {cp$n_exact}/{cp$n_full} resolve exactly; {cp$n_with_unresolved} carry an unresolved display-logic condition.")
    cli::cli_text("Display logic: {cd$n_exact}/{cd$n_conditional} conditional questions enumerated exactly, {cd$n_approx} approximated.")
    cli::cli_text("Loops: {cl$n_known} with a known cap, {cl$n_unknown} unknown.  Item scores: {cs$auto} auto / {cs$inferred} inferred / {cs$manual} manual.")
  }

  n_w <- length(x$warnings)
  cli::cli_h2("QC warnings ({n_w})")
  for (wg in utils::head(x$warnings, 5L)) cli::cli_alert_warning(wg)
  if (n_w > 5L) cli::cli_text("(first 5 shown; full list in {.code $warnings})")

  invisible(x)
}

#' @rdname burden_report
#' @param object A `burden_report` from [burden_report()].
#' @param ... Not used.
#' @export
summary.burden_report <- function(object, ...) {
  structure(list(
    instrument = object$instrument,
    burden     = object$burden,
    benchmark  = attr(object, "benchmark"),
    ppm        = attr(object, "points_per_minute")
  ), class = "summary.burden_report")
}

#' @export
format.summary.burden_report <- function(x, ...) {
  ins <- x$instrument
  cli::cli_fmt({
    cli::cli_h1("{ins$survey_name}")
    cli::cli_text("{ins$n_questions} questions, {ins$n_blocks} blocks, {ins$n_paths} structural paths ({ins$n_complete_paths} complete).")
    for (ln in burden_verdict_line(x$burden, x$ppm, x$benchmark$median_points,
                                   ins$n_complete_paths)) {
      cli::cli_text(ln)
    }
    cli::cli_text("Benchmark: median {x$benchmark$median_points} points across {x$benchmark$n_waves} GfS-scored waves.")
  }, collapse = FALSE)
}

#' @export
print.summary.burden_report <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}
