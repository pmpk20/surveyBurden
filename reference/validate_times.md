# Validate predicted burden against observed completion times

A sanity check, not a calibration study. Predicts each respondent's
burden from their route via
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
(using their real Loop & Merge counts), then compares the predicted
distribution and a predicted-vs-observed regression against observed
completion times.

## Usage

``` r
validate_times(qsf, observed, scheme = gfs_scheme(), trim = c(3, 180))
```

## Arguments

- qsf:

  A `qsf_raw` object or path.

- observed:

  A data frame, or a path to a CSV.

- scheme:

  A
  [`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
  list.

- trim:

  Length-2 numeric: the completion-time range to keep, in minutes. Rows
  outside it, or with a missing or non-finite time, are dropped. This
  filters on duration only; it does not detect non-finishers, so remove
  unfinished responses from `observed` before calling.

## Value

A list:

- n:

  Rows kept after `trim`.

- observed, predicted:

  Quantile vectors (minutes).

- ratio:

  Predicted median / observed median.

- cor:

  Pearson correlation of predicted points and observed minutes.
  Route-level prediction cannot see within-path burden variation, so on
  a real dataset this is typically small. This is the honest fit
  statistic.

- r_squared:

  Ordinary \\R^2\\ of `observed_min ~ predicted_points` (with
  intercept). Do **not** quote the no-intercept model's `r.squared` from
  `lm` below – it is a through-origin pseudo-\\R^2\\, much larger and
  not a variance-explained figure.

- implied_points_per_minute:

  `60 / b`, where `b` is the slope of the through-origin fit
  `observed_seconds ~ 0 + predicted_points` (seconds per point).
  Trim-sensitive; prefer a median-regression estimate from a dedicated
  calibration on real completion times.

- lm:

  The through-origin `lm` (kept for back-compatibility).

- predicted_burden:

  Per-respondent points.

## Details

The observed data frame needs a completion time – `completion_mins`,
`completion_seconds`, or Qualtrics' own `Duration (in seconds)` column
(first found wins; text values are converted to numbers) – and, where
available, the Loop & Merge count columns that
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
recognises (`loop_<question id>`, `loop_<block id>`, or any `loop_*`
column). The label and ImportId rows at the top of a raw Qualtrics CSV
export are removed, with a message, when recognisable.

## Examples

``` r
if (FALSE) { # \dontrun{
# Requires observed completion-time data
vt <- validate_times("survey.qsf", "paradata.csv")
vt$ratio
vt$implied_points_per_minute
} # }
```
