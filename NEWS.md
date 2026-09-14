# surveyBurden 0.1.1

Patch: corrected the documentation of `respondent_burden()` (it predicts
per-respondent burden from loop counts and branch visits, then takes
quantiles — not a route-frequency-weighted average). Rewrote the
population-weighted burden section of the paths-and-display-logic vignette
to match. Added `software_repository_url` to the JOSS paper frontmatter
and expanded the Statement of Need to meet the 250-word guideline.

# surveyBurden 0.1.0

First release.

* `burden_report()` scores a Qualtrics `.qsf` (or a live survey via the API)
  with the published GfS / Axhausen burden weights, reconstructs the respondent
  paths the survey's flow and display logic allow, and reports burden across
  those paths as a structured object.
* `print()` on the report opens with a one-line verdict: the median
  completing-path burden in points and minutes, its ratio to the 399-point GfS
  benchmark, and the range across completing paths. `summary()` gives the same
  headline.
* Supplying observed respondent routes turns the structural profile into a
  population-weighted burden figure.
* `burden_report(quiet = FALSE)` reports progress through the pipeline stages
  with `cli::cli_progress_step()`.
* A survey where every structural path screens out (an unconditional `EndSurvey`
  in the flow) returns a report with `NA` burden and an explanatory warning
  rather than erroring; the per-path burdens are still in `$paths`.
* Lower-level steps are exported for inspection or reuse: `read_qsf()`,
  `fetch_qsf()`, `parse_qsf()`, `classify_question()`, `gfs_weights()`,
  `score_burden()`, `resolve_flow()`, `resolve_paths()`, `path_burden()`,
  `path_burden_profile()`, `respondent_burden()`, `calculation_certainty()`,
  `validate_times()`.
* Five vignettes: "Get started", "Reading the report", "The GfS scoring method",
  "Paths and display logic", and "Calibration and limits".
