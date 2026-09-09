# Changelog

## surveyBurden 0.1.0

First release.

- [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  scores a Qualtrics `.qsf` (or a live survey via the API) with the
  published GfS / Axhausen burden weights, reconstructs the respondent
  paths the survey’s flow and display logic allow, and reports burden
  across those paths as a structured object.
- [`print()`](https://rdrr.io/r/base/print.html) on the report opens
  with a one-line verdict: the median completing-path burden in points
  and minutes, its ratio to the 399-point GfS benchmark, and the range
  across completing paths.
  [`summary()`](https://rdrr.io/r/base/summary.html) gives the same
  headline.
- Supplying observed respondent routes turns the structural profile into
  a population-weighted burden figure.
- `burden_report(quiet = FALSE)` reports progress through the pipeline
  stages with
  [`cli::cli_progress_step()`](https://cli.r-lib.org/reference/cli_progress_step.html).
- A survey where every structural path screens out (an unconditional
  `EndSurvey` in the flow) returns a report with `NA` burden and an
  explanatory warning rather than erroring; the per-path burdens are
  still in `$paths`.
- Lower-level steps are exported for inspection or reuse:
  [`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md),
  [`fetch_qsf()`](https://pmpk20.github.io/surveyBurden/reference/fetch_qsf.md),
  [`parse_qsf()`](https://pmpk20.github.io/surveyBurden/reference/parse_qsf.md),
  [`classify_question()`](https://pmpk20.github.io/surveyBurden/reference/classify_question.md),
  [`gfs_weights()`](https://pmpk20.github.io/surveyBurden/reference/gfs_weights.md),
  [`score_burden()`](https://pmpk20.github.io/surveyBurden/reference/score_burden.md),
  [`resolve_flow()`](https://pmpk20.github.io/surveyBurden/reference/resolve_flow.md),
  [`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md),
  [`path_burden()`](https://pmpk20.github.io/surveyBurden/reference/path_burden.md),
  [`path_burden_profile()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_profile.md),
  [`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md),
  [`calculation_certainty()`](https://pmpk20.github.io/surveyBurden/reference/calculation_certainty.md),
  [`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md).
- Five vignettes: “Get started”, “Reading the report”, “The GfS scoring
  method”, “Paths and display logic”, and “Calibration and limits”.
