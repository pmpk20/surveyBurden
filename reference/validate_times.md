# Validate predicted burden against observed completion times

A sanity check, not a calibration study. Predicts each respondent's
burden from their route via
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
(using their real Loop & Merge counts), then compares the predicted
distribution and a predicted-vs-observed regression against observed
completion times.

## Usage

``` r
validate_times(qsf, observed, weights = gfs_weights(), trim = c(3, 180))
```

## Arguments

- qsf:

  A `qsf_raw` object or path.

- observed:

  A data frame, or a path to a CSV.

- weights:

  A
  [`gfs_weights()`](https://pmpk20.github.io/surveyBurden/reference/gfs_weights.md)
  list.

- trim:

  Completion-minute range to keep (drops non-finishers and stalls).

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

  Slope of `observed_seconds ~ 0 + predicted_points`. Trim-sensitive;
  prefer a median-regression estimate from a dedicated calibration on
  real completion times.

- lm:

  The through-origin `lm` (kept for back-compatibility).

- predicted_burden:

  Per-respondent points.

## Details

The observed data frame needs `completion_seconds` or `completion_mins`
and, where available, the Loop & Merge count columns that
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
recognises (`loop_<question id>`, `loop_<block id>`, or any `loop_*`
column).
