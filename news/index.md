# Changelog

## surveyBurden (development version)

- [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  gains a `quiet` argument and, by default, reports progress through the
  pipeline stages with
  [`cli::cli_progress_step()`](https://cli.r-lib.org/reference/cli_progress_step.html).
- [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  no longer errors on a survey where every structural path screens out
  (an unconditional `EndSurvey` in the flow). It now returns a report
  with `NA` burden, `basis = "none"` and an explanatory warning; the
  per-path burdens are still in `$paths`.

## surveyBurden 0.1.0

- First release.
- [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  scores a Qualtrics `.qsf` (or a live survey via the API) with the GfS
  / Axhausen burden weights, reconstructs the respondent paths the
  survey’s flow and display logic allow, and reports burden across those
  paths.
- Lower-level steps are exported:
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
