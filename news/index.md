# Changelog

## surveyBurden (development version)

- When `routes` is supplied,
  [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  now includes the arithmetic mean and the 10th and 90th percentiles of
  per-respondent predictions in `$population` and its printed table,
  alongside the existing five statistics.

## surveyBurden 0.2.0

CRAN preparation release.

- Added runnable `@examples` to all exported functions using the shipped
  demo fixture (`demo_travel_survey.qsf`).
- Switched
  [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  and
  [`calculation_certainty()`](https://pmpk20.github.io/surveyBurden/reference/calculation_certainty.md)
  examples from `\dontrun{}` to `\donttest{}` with the demo fixture.
- Added the Heimgartner and Axhausen (2024) DOI to the DESCRIPTION and
  to the documentation of
  [`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md),
  [`score_burden()`](https://pmpk20.github.io/surveyBurden/reference/score_burden.md)
  and
  [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md).
- Updated `.Rbuildignore` to exclude manuscript and temporary files.
- Updated roxygen2 to 8.1.0.

## surveyBurden 0.1.1

Patch: corrected the documentation of
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
(it predicts per-respondent burden from loop counts and branch visits,
then takes quantiles — not a route-frequency-weighted average). Rewrote
the population-weighted burden section of the paths-and-display-logic
vignette to match. Added `software_repository_url` to the JOSS paper
frontmatter and expanded the Statement of Need to meet the 250-word
guideline.

## surveyBurden 0.1.0

First release.

- [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  scores a Qualtrics `.qsf` (or a live survey via the API) with the GfS+
  burden-point scheme (extending Heimgartner and Axhausen 2024),
  reconstructs the respondent paths the survey’s flow and display logic
  allow, and reports burden across those paths as a structured object.
- [`print()`](https://rdrr.io/r/base/print.html) on the report opens
  with a one-line verdict: the median completing-path burden in points
  and minutes, its ratio to the 399-point GfS+ benchmark, and the range
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
  [`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md),
  [`score_burden()`](https://pmpk20.github.io/surveyBurden/reference/score_burden.md),
  [`resolve_flow()`](https://pmpk20.github.io/surveyBurden/reference/resolve_flow.md),
  [`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md),
  [`path_burden()`](https://pmpk20.github.io/surveyBurden/reference/path_burden.md),
  [`path_burden_profile()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_profile.md),
  [`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md),
  [`calculation_certainty()`](https://pmpk20.github.io/surveyBurden/reference/calculation_certainty.md),
  [`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md).
- Five vignettes: “Get started”, “Reading the report”, “The GfS+ scoring
  method”, “Paths and display logic”, and “Calibration and limits”.
