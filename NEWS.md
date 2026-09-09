# surveyBurden (development version)

* `burden_report()` is ~4x faster (INFUZE core survey: 17s to 4s). It now
  parses, scores and resolves the instrument once and threads the results
  through the pipeline instead of each step redoing that work. `path_burden()`,
  `path_burden_profile()`, `calculation_certainty()`, `respondent_burden()`,
  `resolve_paths()` and `instrument_summary()` gain optional arguments for the
  precomputed pieces; output is unchanged.
* `burden_report()` gains a `quiet` argument and, by default, reports progress
  through the pipeline stages with `cli::cli_progress_step()`.
* `burden_report()` no longer errors on a survey where every structural path
  screens out (an unconditional `EndSurvey` in the flow). It now returns a
  report with `NA` burden, `basis = "none"` and an explanatory warning; the
  per-path burdens are still in `$paths`.

# surveyBurden 0.1.0

* First release.
* `burden_report()` scores a Qualtrics `.qsf` (or a live survey via the API)
  with the GfS / Axhausen burden weights, reconstructs the respondent paths the
  survey's flow and display logic allow, and reports burden across those paths.
* Lower-level steps are exported: `read_qsf()`, `fetch_qsf()`, `parse_qsf()`,
  `classify_question()`, `gfs_weights()`, `score_burden()`, `resolve_flow()`,
  `resolve_paths()`, `path_burden()`, `path_burden_profile()`,
  `respondent_burden()`, `calculation_certainty()`, `validate_times()`.
