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
  finished_only = TRUE,
  overrides = NULL,
  choice_tasks = NULL
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
  outside it, or with a missing or non-finite time, are dropped, and the
  printed summary says how many. The default `c(3, 180)` drops times too
  short for anyone to have read the survey and times over three hours,
  which usually mean the survey was left open. The headline rate uses
  medians, so it moves little with the trim; widen it (e.g. `c(0, Inf)`)
  to keep every finisher.

- finished_only:

  If `TRUE` (default) and `observed` has a `Finished` column, keep only
  respondents who finished. A break-off's duration does not measure the
  time to complete the survey.

- overrides:

  Optional named numeric vector of GfS+ points that replace the computed
  score of the named questions, e.g. `c(QID51 = 10)`; passed to
  [`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md).

- choice_tasks:

  Optional data frame declaring stated-choice tasks (`question_id`,
  `n_alternatives`, `n_attributes`), scored by the GfS stated-choice
  rule. Passed to
  [`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md).

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

  The headline rate: median predicted points divided by median observed
  minutes, over the kept respondents. Robust to a few very long
  completion times.

- ols_points_per_minute:

  `60 / b`, where `b` is the slope of the through-origin fit
  `observed_seconds ~ 0 + predicted_points` (seconds per point). Kept
  for comparison; long completion times dominate it, so it is not the
  headline. In version 0.2.0 this was `implied_points_per_minute`.

- lm:

  The through-origin `lm` (kept for back-compatibility).

- n_trimmed, trim:

  Rows dropped by `trim` (after `finished_only`), and the range used.

- predicted_burden, observed_minutes:

  Per-respondent points and observed minutes for the kept respondents.

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
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                         package = "surveyBurden")
# Two finished respondents with their completion times (toy data)
observed <- data.frame(
  ResponseId = c("R_1", "R_2"),
  Finished   = c(1, 1),
  QID2  = c("1", "1"),
  QID3  = c("1", "2"),
  QID4  = c("2", "3"),
  QID6  = c("1", "4"),
  QID9  = c("2", NA),
  QID10 = c("1", NA),
  QID22 = c("3", "2"),
  QID26 = c("1", "2"),
  completion_seconds = c(720, 540)
)
vt <- validate_times(qsf_path, observed)
vt
#> 
#> ── Predicted vs observed completion time ──
#> 
#> 2 respondents; respondent burden at 12 points per minute.
#> Completion times outside 3 to 180 minutes or missing: 0 dropped.
#>                    10%  25%   50%   75%   90%
#> ---------------------------------------------
#> Observed minutes   9.3  9.8  10.5  11.2  11.7
#> Predicted minutes  3.6  4.5   6.0   7.4   8.3
#> Median ratio (predicted / observed): 0.57
#> Correlation (points vs minutes): 1.00
#> Implied points per minute (median points / median minutes): 6.8
vt$implied_points_per_minute
#> [1] 6.809524
```
