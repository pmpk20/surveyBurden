# surveyBurden 0.2.0

## New features

* New `realised_burden()` scores the questions each respondent actually
  answered, using exported response data. Case-insensitive `ExportTag`
  matching.
* New `validate_catalogue()` checks and coerces a hand-built question
  catalogue, enabling platform-agnostic scoring without a QSF file.
* New "Extensions" vignette showing the catalogue schema and a worked
  example of scoring a non-Qualtrics survey.
* New "Realised burden" vignette with a Qualtrics-export walkthrough.
* `gfs_weights()` renamed to `gfs_scheme()`, and the `weights` argument of
  the scoring and reporting functions renamed to `scheme`. The old names
  have been removed, not deprecated: update calls to `gfs_scheme()` and
  `scheme =`.
* `burden_report()` gains a `words_per_line` argument for per-respondent
  reading-load estimation.
* `burden_report()` gains a `max_paths` argument (default 10,000), passed to
  `resolve_flow()`, so surveys with heavily branching flows can be analysed
  by raising the cap. The "too many paths" error now suggests it.
* When `routes` is supplied, `burden_report()` now includes the arithmetic
  mean and the 10th and 90th percentiles of per-respondent predictions in
  `$population` and its printed table, alongside the existing five statistics.
* Scoring and documentation now use "GfS+" to distinguish the package's
  extended scheme (with documented inference rules for dropdowns, sliders,
  and multi-answer matrices) from the original GfS table.

## Performance

* `path_burden_profile()`, and so the display-logic step of `burden_report()`,
  is about 15x faster on surveys with many paths. Results are unchanged.
* `resolve_paths()` and `resolve_flow()` are about twice as fast on surveys
  with many paths. Results are unchanged.

## Bug fixes

* `parse_qsf()` no longer fails on sliders whose tick labels Qualtrics stores
  as numbers rather than text.
* Surveys whose flow sits inside an `Authenticator` node are now resolved;
  previously the node and everything in it was skipped, giving an empty path
  and a burden of 0.
* A `Branch`, `Group` or `BlockRandomizer` flow node with no child flow no
  longer crashes `resolve_flow()`; it is treated as empty.
* Vignettes updated from `weights =` to `scheme =` after the rename.
* `realised_burden()` now reads a `Finished` column coded `TRUE`/`FALSE` or
  yes/no (any case) as well as `1`/`0`. Blank or unrecognised values are
  `NA` (status unknown); previously `TRUE`/`FALSE` became `NA`, and values
  such as `"2"` or `"0.5"` were misread as finished or not finished.

## Documentation

* Added runnable `@examples` to all exported functions using the shipped
  demo fixture (`demo_travel_survey.qsf`).
* Switched `burden_report()` and `calculation_certainty()` examples from
  `\dontrun{}` to `\donttest{}` with the demo fixture.
* Added the Heimgartner and Axhausen (2024) DOI to the DESCRIPTION and to
  the documentation of `gfs_scheme()`, `score_burden()` and
  `burden_report()`.
* Updated `.Rbuildignore` to exclude manuscript and temporary files.
* Updated roxygen2 to 8.1.0.

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
  with the GfS+ burden-point scheme (extending Heimgartner and Axhausen 2024), reconstructs the respondent
  paths the survey's flow and display logic allow, and reports burden across
  those paths as a structured object.
* `print()` on the report opens with a one-line verdict: the median
  completing-path burden in points and minutes, its ratio to the 399-point GfS+
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
  `fetch_qsf()`, `parse_qsf()`, `classify_question()`, `gfs_scheme()`,
  `score_burden()`, `resolve_flow()`, `resolve_paths()`, `path_burden()`,
  `path_burden_profile()`, `respondent_burden()`, `calculation_certainty()`,
  `validate_times()`.
* Five vignettes: "Get started", "Reading the report", "The GfS+ scoring method",
  "Paths and display logic", and "Calibration and limits".
