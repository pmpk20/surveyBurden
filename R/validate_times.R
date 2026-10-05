#' Validate predicted burden against observed completion times
#'
#' A sanity check, not a calibration study. Gives each respondent a burden in
#' GfS+ points and compares it with their observed completion time: the
#' predicted and observed distributions, their correlation, and the
#' points-per-minute rate the data imply.
#'
#' Each respondent's burden comes from one of three bases (`basis`):
#' \describe{
#'   \item{`"shown"`}{[realised_exposure()]: the GfS+ points of every item
#'     displayed to the respondent, summed over blocks -- including
#'     descriptive text and questions left blank. This is the respondent
#'     burden \eqn{B_i} (every item on the respondent's route) and is the
#'     recommended basis when the export allows the flow to be replayed.
#'     Errors from [realised_exposure()] are not caught.}
#'   \item{`"realised"`}{[realised_burden()]: the points of the questions the
#'     respondent actually answered. Needs response columns that map to the
#'     survey's questions, as in a raw Qualtrics CSV export.}
#'   \item{`"route"`}{[respondent_burden()]: the points predicted from the
#'     respondent's route, using the Loop & Merge count columns it recognises
#'     (`loop_<question id>`, `loop_<block id>`, or any `loop_*` column).
#'     Without such columns every respondent gets the same prediction.}
#' }
#' `"auto"` (default) uses `"realised"` when the response columns map to
#' questions and `"route"` otherwise; it never picks `"shown"`, which must be
#' asked for.
#'
#' The observed data need a completion time -- `completion_mins`,
#' `completion_seconds`, or Qualtrics' own `Duration (in seconds)` column
#' (first found wins; text values are converted to numbers). The label and
#' ImportId rows at the top of a raw Qualtrics CSV export are removed, with a
#' message, when recognisable.
#'
#' @param qsf A `qsf_raw` object or path.
#' @param observed A data frame, or the path to a CSV (e.g. the raw Qualtrics
#'   export).
#' @param scheme A [gfs_scheme()] list.
#' @param trim Length-2 numeric: the completion-time range to keep, in
#'   minutes. Rows outside it, or with a missing or non-finite time, are
#'   dropped.
#' @param basis `"auto"`, `"realised"`, `"route"` or `"shown"`: where each
#'   respondent's burden comes from (see Details). `"shown"` is recommended
#'   when the export allows replaying the flow.
#' @param finished_only If `TRUE` (default) and `observed` has a `Finished`
#'   column, keep only respondents who finished. A break-off's duration does
#'   not measure the time to complete the survey.
#'
#' @return A `burden_time_validation` list (printed as a short summary):
#'   \describe{
#'     \item{n}{Rows kept after `finished_only` and `trim`.}
#'     \item{basis}{The basis used: `"shown"`, `"realised"` or `"route"`.}
#'     \item{observed, predicted}{Quantile vectors (minutes).}
#'     \item{ratio}{Predicted median / observed median.}
#'     \item{cor}{Pearson correlation of predicted points and observed
#'       minutes; `NA` when every respondent has the same prediction. This is
#'       the honest fit statistic.}
#'     \item{r_squared}{Ordinary \eqn{R^2} of `observed_min ~ predicted_points`
#'       (with intercept). Do **not** quote the no-intercept model's `r.squared`
#'       from `lm` below -- it is a through-origin pseudo-\eqn{R^2}, much larger
#'       and not a variance-explained figure.}
#'     \item{implied_points_per_minute}{`60 / b`, where `b` is the slope of
#'       the through-origin fit `observed_seconds ~ 0 + predicted_points`
#'       (seconds per point). Trim-sensitive; prefer a median-regression
#'       estimate from a dedicated calibration on real completion times.}
#'     \item{lm}{The through-origin `lm` (kept for back-compatibility).}
#'     \item{predicted_burden}{Per-respondent points.}
#'   }
#'
#' @examples
#' \dontrun{
#' # Requires observed completion-time data
#' vt <- validate_times("survey.qsf", "export.csv")
#' vt
#' vt$implied_points_per_minute
#' }
#'
#' @export
validate_times <- function(qsf, observed, scheme = gfs_scheme(), trim = c(3, 180),
                           basis = c("auto", "realised", "route", "shown"),
                           finished_only = TRUE) {
  basis <- match.arg(basis)
  if (!inherits(qsf, "qsf_raw")) qsf <- read_qsf(qsf)
  observed <- read_responses(observed, "observed")
  observed <- drop_qualtrics_header_rows(observed)$data
  ppm <- scheme$points_per_minute

  # realised burden is computed on the full data: row subsetting would drop
  # the ImportId attribute the column mapping uses
  realised <- NULL
  if (identical(basis, "shown")) {
    realised <- shown_points_per_respondent(qsf, observed, scheme)
  } else if (!identical(basis, "route")) {
    # realised_burden() also predicts each route; that prediction is not used
    # here, so its route-matching warning is muffled
    realised <- tryCatch(
      withCallingHandlers(
        suppressMessages(realised_burden(qsf, observed, scheme = scheme))$realised_points,
        warning = function(w) {
          if (grepl("did not match any of the", conditionMessage(w), fixed = TRUE)) {
            invokeRestart("muffleWarning")
          }
        }),
      error = function(e) if (identical(basis, "realised")) stop(e) else NULL)
    basis <- if (is.null(realised)) "route" else "realised"
  }

  mins <- completion_minutes(observed)
  keep <- is.finite(mins) & mins >= trim[1] & mins <= trim[2]
  if (finished_only) {
    fin <- detect_finished(observed)
    if (!all(is.na(fin))) keep <- keep & fin %in% TRUE
  }
  o <- observed[keep, , drop = FALSE]
  o$completion_mins <- mins[keep]

  if (!identical(basis, "route")) {
    o$pred_pts <- realised[keep]
  } else {
    o$pred_pts <- respondent_burden(qsf, routes = o, scheme = scheme)$pred_pts
  }
  o$pred_min <- o$pred_pts / ppm

  probs <- c(.1, .25, .5, .75, .9)
  fit <- stats::lm(I(completion_mins * 60) ~ 0 + pred_pts, data = o)
  fit_int <- stats::lm(completion_mins ~ pred_pts, data = o)
  varies <- isTRUE(stats::sd(o$pred_pts, na.rm = TRUE) > 0)

  structure(list(
    n = nrow(o),
    basis = basis,
    observed  = stats::quantile(o$completion_mins, probs),
    predicted = stats::quantile(o$pred_min, probs, na.rm = TRUE),
    ratio = stats::median(o$pred_min, na.rm = TRUE) / stats::median(o$completion_mins),
    cor = if (varies) stats::cor(o$pred_pts, o$completion_mins, use = "complete.obs") else NA_real_,
    r_squared = summary(fit_int)$r.squared,
    implied_points_per_minute = 60 / stats::coef(fit)[["pred_pts"]],
    lm = fit,
    predicted_burden = o$pred_pts
  ), class = "burden_time_validation", points_per_minute = ppm)
}

#' @export
print.burden_time_validation <- function(x, ...) {
  basis_txt <- switch(x$basis,
    shown    = "shown burden (every item displayed to each respondent)",
    realised = "realised burden (questions each respondent answered)",
    "route prediction (respondent_burden())")
  tab <- rbind(
    c("", "10%", "25%", "50%", "75%", "90%"),
    c("Observed minutes",  sprintf("%.1f", x$observed)),
    c("Predicted minutes", sprintf("%.1f", x$predicted)))
  cli::cli_h2("Predicted vs observed completion time")
  cli::cli_text("{x$n} respondent{?s}; burden from {basis_txt}, at {attr(x, 'points_per_minute')} points per minute.")
  cli::cli_verbatim(render_table(tab))
  cli::cli_text("Median ratio (predicted / observed): {sprintf('%.2f', x$ratio)}")
  cli::cli_text("Correlation (points vs minutes): {if (is.na(x$cor)) 'NA (every respondent has the same prediction)' else sprintf('%.2f', x$cor)}")
  cli::cli_text("Implied points per minute: {sprintf('%.1f', x$implied_points_per_minute)}")
  invisible(x)
}

#' Shown points per respondent, in the row order of `observed`: the sum of
#' `shown_points` over reached blocks from [realised_exposure()], matched on the same
#' id column it uses (or row position when there is none). Respondents absent
#' from the exposure table get NA. Errors from realised_exposure() propagate.
#' @noRd
shown_points_per_respondent <- function(qsf, observed, scheme) {
  ex <- suppressMessages(realised_exposure(qsf, observed, scheme = scheme))
  id_col <- resolve_id_col(observed, NULL)
  ids <- if (!is.null(id_col)) observed[[id_col]] else seq_len(nrow(observed))
  # blocks a respondent never reached have NA shown points: they add nothing,
  # but a respondent with no reached block at all stays NA
  sums <- tapply(ex$shown_points, as.character(ex$response_id), function(p)
    if (all(is.na(p))) NA_real_ else sum(p, na.rm = TRUE))
  unname(as.numeric(sums[match(as.character(ids), names(sums))]))
}

#' Completion time in minutes from the first duration column found:
#' `completion_mins`, `completion_seconds`, or Qualtrics' `Duration (in
#' seconds)` (also as `read.csv()` renames it). Text values are converted to
#' numbers; anything unparseable becomes NA and is later dropped by the trim.
#' @noRd
completion_minutes <- function(observed) {
  num <- function(v) suppressWarnings(as.numeric(as.character(v)))
  if (!is.null(observed[["completion_mins"]])) return(num(observed[["completion_mins"]]))
  for (col in c("completion_seconds", "Duration (in seconds)", "Duration..in.seconds.")) {
    if (!is.null(observed[[col]])) return(num(observed[[col]]) / 60)
  }
  cli::cli_abort(c(
    "No completion-time column found in {.arg observed}.",
    i = "Supply {.field completion_mins}, {.field completion_seconds}, or Qualtrics' {.field Duration (in seconds)}."
  ))
}
