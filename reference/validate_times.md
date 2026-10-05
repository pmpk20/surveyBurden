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
  basis = c("auto", "realised", "route", "shown"),
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

- basis:

  `"auto"`, `"realised"`, `"route"` or `"shown"`: where each
  respondent's burden comes from (see Details). `"shown"` is recommended
  when the export allows replaying the flow.

- finished_only:

  If `TRUE` (default) and `observed` has a `Finished` column, keep only
  respondents who finished. A break-off's duration does not measure the
  time to complete the survey.

## Value

A `burden_time_validation` list (printed as a short summary):

- n:

  Rows kept after `finished_only` and `trim`.

- basis:

  The basis used: `"shown"`, `"realised"` or `"route"`.

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

Each respondent's burden comes from one of three bases (`basis`):

- `"shown"`:

  [`realised_exposure()`](https://pmpk20.github.io/surveyBurden/reference/realised_exposure.md):
  the GfS+ points of every item displayed to the respondent, summed over
  blocks – including descriptive text and questions left blank. This is
  the respondent burden \\B_i\\ (every item on the respondent's route)
  and is the recommended basis when the export allows the flow to be
  replayed. Errors from
  [`realised_exposure()`](https://pmpk20.github.io/surveyBurden/reference/realised_exposure.md)
  are not caught.

- `"realised"`:

  [`realised_burden()`](https://pmpk20.github.io/surveyBurden/reference/realised_burden.md):
  the points of the questions the respondent actually answered. Needs
  response columns that map to the survey's questions, as in a raw
  Qualtrics CSV export.

- `"route"`:

  [`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md):
  the points predicted from the respondent's route, using the Loop &
  Merge count columns it recognises (`loop_<question id>`,
  `loop_<block id>`, or any `loop_*` column). Without such columns every
  respondent gets the same prediction.

`"auto"` (default) uses `"realised"` when the response columns map to
questions and `"route"` otherwise; it never picks `"shown"`, which must
be asked for.

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
