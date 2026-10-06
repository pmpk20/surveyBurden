# Validate predicted burden against observed completion times

A sanity check, not a calibration study. Gives each respondent a burden
in GfS+ points and compares it with their observed completion time: the
predicted and observed distributions, their correlation, and the
points-per-minute rate the data imply.

## Usage

``` r
validate_times(
  qsf,
  observed,
  scheme = gfs_scheme(),
  trim = c(3, 180),
  finished_only = TRUE
)
```

## Arguments

- qsf:

  A `qsf_raw` object or path.

- observed:

  A data frame, or the path to a CSV (e.g. the raw Qualtrics export).

- scheme:

  A
  [`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
  list.

- trim:

  Length-2 numeric: the completion-time range to keep, in minutes. Rows
  outside it, or with a missing or non-finite time, are dropped.

- finished_only:

  If `TRUE` (default) and `observed` has a `Finished` column, keep only
  respondents who finished. A break-off's duration does not measure the
  time to complete the survey.

## Value

A `burden_time_validation` list (printed as a short summary):

- n:

  Rows kept after `finished_only` and `trim`.

- observed, predicted:

  Quantile vectors (minutes).

- ratio:

  Predicted median / observed median.

- cor:

  Pearson correlation of predicted points and observed minutes; `NA`
  when every respondent has the same prediction. This is the honest fit
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

Each respondent's burden is their
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md):
the GfS+ points of every item displayed to them, including descriptive
text and questions left blank. Errors from
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
are not caught.

The observed data need a completion time – `completion_mins`,
`completion_seconds`, or Qualtrics' own `Duration (in seconds)` column
(first found wins; text values are converted to numbers). The label and
ImportId rows at the top of a raw Qualtrics CSV export are removed, with
a message, when recognisable.

## Examples

``` r
if (FALSE) { # \dontrun{
# Requires observed completion-time data
vt <- validate_times("survey.qsf", "export.csv")
vt
vt$implied_points_per_minute
} # }
```
