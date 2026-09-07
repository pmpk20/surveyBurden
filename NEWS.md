# surveyBurden 0.1.0

* First release.
* `burden_report()` scores a Qualtrics `.qsf` (or a live survey via the API)
  with the GfS / Axhausen burden weights, reconstructs the respondent paths the
  survey's flow and display logic allow, and reports burden across those paths.
* Lower-level steps are exported: `read_qsf()`, `fetch_qsf()`, `parse_qsf()`,
  `classify_question()`, `gfs_weights()`, `score_burden()`, `resolve_flow()`,
  `resolve_paths()`, `path_burden()`, `path_burden_profile()`,
  `respondent_burden()`, `calculation_certainty()`, `validate_times()`.
