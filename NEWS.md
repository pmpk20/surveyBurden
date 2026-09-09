# surveyBurden (development version)

* `burden_report()` is faster again: `parse_qsf()` and `score_burden()` now
  build their catalogue in one pass instead of constructing a one-row tibble
  per question and row-binding hundreds of them (that machinery was ~60% of the
  remaining runtime). INFUZE core survey: ~4s to ~3s; the bundled demo ~1s to
  ~0.5s. Catalogue contents are byte-identical.
* **Breaking (internal API):** `classify_question()` now returns a named `list`
  rather than a one-row tibble. It is a building block for `parse_qsf()`, which
  is unchanged. `score_burden()`'s output is unchanged.
* Each question's display-logic tree is parsed once per `burden_report()` and
  shared between the burden engine and the certainty breakdown, instead of
  being parsed independently by each.
* The display-logic convolution builds its intermediate `(burden, weight)`
  frames with a bare constructor instead of `data.frame()` (called 1000+ times
  on a survey with heavy display logic). Numbers are unchanged.
* A survey with several block randomisers now raises **one** combined
  "BlockRandomizer" warning that names the flow nodes, instead of one warning
  per randomiser.
* Internal cleanups with no change to any reported number: the display-logic
  exact-enumeration cap is now a single shared constant (was duplicated between
  the burden calc and the certainty breakdown, so they could drift); question
  stems are HTML-stripped once per question instead of twice.
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
