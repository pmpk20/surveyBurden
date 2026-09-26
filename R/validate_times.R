#' Validate predicted burden against observed completion times
#'
#' A sanity check, not a calibration study. Predicts each respondent's burden
#' from their route via [respondent_burden()] (using their real Loop & Merge
#' counts), then compares the predicted distribution and a predicted-vs-observed
#' regression against observed completion times.
#'
#' The observed data frame needs a completion time -- `completion_mins`,
#' `completion_seconds`, or Qualtrics' own `Duration (in seconds)` column
#' (first found wins; text values are converted to numbers) -- and, where
#' available, the Loop & Merge count columns that [respondent_burden()]
#' recognises (`loop_<question id>`, `loop_<block id>`, or any `loop_*`
#' column). The label and ImportId rows at the top of a raw Qualtrics CSV
#' export are removed, with a message, when recognisable.
#'
#' @param qsf A `qsf_raw` object or path.
#' @param observed A data frame, or a path to a CSV.
#' @param scheme A [gfs_scheme()] list.
#' @param trim Length-2 numeric: the completion-time range to keep, in
#'   minutes. Rows outside it, or with a missing or non-finite time, are
#'   dropped. This filters on duration only; it does not detect non-finishers,
#'   so remove unfinished responses from `observed` before calling.
#'
#' @return A list:
#'   \describe{
#'     \item{n}{Rows kept after `trim`.}
#'     \item{observed, predicted}{Quantile vectors (minutes).}
#'     \item{ratio}{Predicted median / observed median.}
#'     \item{cor}{Pearson correlation of predicted points and observed minutes.
#'       Route-level prediction cannot see within-path burden variation, so on a
#'       real dataset this is typically small. This is the honest fit statistic.}
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
#' vt <- validate_times("survey.qsf", "paradata.csv")
#' vt$ratio
#' vt$implied_points_per_minute
#' }
#'
#' @export
validate_times <- function(qsf, observed, scheme = gfs_scheme(), trim = c(3, 180)) {
  if (!inherits(qsf, "qsf_raw")) qsf <- read_qsf(qsf)
  if (is.character(observed)) observed <- utils::read.csv(observed)
  observed <- drop_qualtrics_header_rows(observed)$data

  observed$completion_mins <- completion_minutes(observed)
  o <- observed[is.finite(observed$completion_mins) &
                  observed$completion_mins >= trim[1] &
                  observed$completion_mins <= trim[2], , drop = FALSE]

  ppm <- scheme$points_per_minute

  pr <- respondent_burden(qsf, routes = o, scheme = scheme)
  o$pred_pts <- pr$pred_pts
  o$pred_min <- pr$pred_min

  probs <- c(.1, .25, .5, .75, .9)
  fit <- stats::lm(I(completion_mins * 60) ~ 0 + pred_pts, data = o)
  fit_int <- stats::lm(completion_mins ~ pred_pts, data = o)

  list(
    n = nrow(o),
    observed  = stats::quantile(o$completion_mins, probs),
    predicted = stats::quantile(o$pred_min, probs, na.rm = TRUE),
    ratio = stats::median(o$pred_min, na.rm = TRUE) / stats::median(o$completion_mins),
    cor = stats::cor(o$pred_pts, o$completion_mins),
    r_squared = summary(fit_int)$r.squared,
    implied_points_per_minute = 60 / stats::coef(fit)[["pred_pts"]],
    lm = fit,
    predicted_burden = o$pred_pts
  )
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
