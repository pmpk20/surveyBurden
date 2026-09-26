# Changelog

## surveyBurden 0.2.0

### New features

- New
  [`realised_burden()`](https://pmpk20.github.io/surveyBurden/reference/realised_burden.md)
  scores the questions each respondent actually answered, using exported
  response data. Case-insensitive `ExportTag` matching.
- New
  [`validate_catalogue()`](https://pmpk20.github.io/surveyBurden/reference/validate_catalogue.md)
  checks and coerces a hand-built question catalogue, enabling
  platform-agnostic scoring without a QSF file.
- New “Extensions” vignette showing the catalogue schema and a worked
  example of scoring a non-Qualtrics survey.
- New “Realised burden” vignette with a Qualtrics-export walkthrough.
- `gfs_weights()` renamed to
  [`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md),
  and the `weights` argument of the scoring and reporting functions
  renamed to `scheme`. The old names have been removed, not deprecated:
  update calls to
  [`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
  and `scheme =`.
- [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  gains a `words_per_line` argument for per-respondent reading-load
  estimation.
- [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  gains a `max_paths` argument (default 10,000), passed to
  [`resolve_flow()`](https://pmpk20.github.io/surveyBurden/reference/resolve_flow.md),
  so surveys with heavily branching flows can be analysed by raising the
  cap. The “too many paths” error now suggests it.
- When `routes` is supplied,
  [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  now includes the arithmetic mean and the 10th and 90th percentiles of
  per-respondent predictions in `$population` and its printed table,
  alongside the existing five statistics.
- Scoring and documentation now use “GfS+” to distinguish the package’s
  extended scheme (with documented inference rules for dropdowns,
  sliders, and multi-answer matrices) from the original GfS table.

### Performance

- [`path_burden_profile()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_profile.md),
  and so the display-logic step of
  [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md),
  is about 15x faster on surveys with many paths. Results are unchanged.
- [`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md)
  and
  [`resolve_flow()`](https://pmpk20.github.io/surveyBurden/reference/resolve_flow.md)
  are about twice as fast on surveys with many paths. Results are
  unchanged.

### Bug fixes

- [`parse_qsf()`](https://pmpk20.github.io/surveyBurden/reference/parse_qsf.md)
  no longer fails on sliders whose tick labels Qualtrics stores as
  numbers rather than text.
- Surveys whose flow sits inside an `Authenticator` node are now
  resolved; previously the node and everything in it was skipped, giving
  an empty path and a burden of 0.
- A `Branch`, `Group` or `BlockRandomizer` flow node with no child flow
  no longer crashes
  [`resolve_flow()`](https://pmpk20.github.io/surveyBurden/reference/resolve_flow.md);
  it is treated as empty.
- Vignettes updated from `weights =` to `scheme =` after the rename.
- [`realised_burden()`](https://pmpk20.github.io/surveyBurden/reference/realised_burden.md)
  now reads a `Finished` column coded `TRUE`/`FALSE` or yes/no (any
  case) as well as `1`/`0`. Blank or unrecognised values are `NA`
  (status unknown); previously `TRUE`/`FALSE` became `NA`, and values
  such as `"2"` or `"0.5"` were misread as finished or not finished.
- [`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
  (and `burden_report(routes = ...)`) now sets `matched = TRUE` only
  when a respondent’s optional-block set matches an enumerated path
  exactly. Routes that fall back to the path with no optional blocks
  were previously reported as matched; they are now `matched = FALSE`
  and the warning says which fallback path each group received.
  Predictions are unchanged.
- [`realised_burden()`](https://pmpk20.github.io/surveyBurden/reference/realised_burden.md):
  columns mapped through a `col_map` attribute now keep their Loop &
  Merge iteration, from an `N_` column-name prefix or from a
  `list(qid = , iteration = )` entry. Previously every mapped column was
  treated as iteration 0, so answers from different iterations of a
  looped question were merged and scored once. The help and vignette now
  also state that `col_map` overrides automatic column matching.
- [`realised_burden()`](https://pmpk20.github.io/surveyBurden/reference/realised_burden.md)
  removes the question-label and ImportId rows at the top of a raw
  Qualtrics CSV export, with a message, when it can recognise them.
  Previously they were scored as respondents. Unrecognised rows are
  always kept.
- Display-logic reachability: a question is now classed as never shown
  on a path only when its logic is shown to be false there. Previously
  any reference to a question off the path ruled it out, which was wrong
  for OR conditions, `ElseIf` groups and negated conditions (“not
  selected”, “not displayed”), and understated that path’s burden.
  Questions that depend on a ruled-out question are now re-checked, and
  enumeration fixes off-path trigger questions as unanswered. On the
  surveys tested the burden figures are unchanged; the fix matters for
  surveys with such logic across branches.
- [`classify_reachability()`](https://pmpk20.github.io/surveyBurden/reference/classify_reachability.md)
  gains a `display_logic` argument (the questions’ `DisplayLogic`
  trees). Without it the logic cannot be evaluated, so it no longer
  classes any question as unreachable;
  [`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md)
  supplies the trees.

### Documentation

- Interpretation wording corrected throughout. The structural profile
  was described as counting each combination “once” with unweighted
  quantiles; in fact each modelled state carries an equal model weight,
  each path’s weights sum to 1, and the report gives each complete path
  equal total weight. “Feasible” / “achievable” paths are now described
  as the paths the flow allows, with a note that branch conditions are
  not checked against each other. “Exact” is qualified: the printed
  certainty lines now read “have no unresolved display-logic question”
  and “enumerated in full within the model”, and
  [`?calculation_certainty`](https://pmpk20.github.io/surveyBurden/reference/calculation_certainty.md)
  explains that neither means the result matches the live survey. The
  `index` column is documented as `points / rare_threshold` (it can
  exceed 1).
- [`realised_burden()`](https://pmpk20.github.io/surveyBurden/reference/realised_burden.md)
  now has an explicit operational definition: a question’s full score
  counts when at least one mapped response column is non-blank, per
  detected loop iteration. It does not measure exposure, reading time or
  partial completion, and `n_questions_answered` counts
  question-iteration pairs. The vignette no longer presents a
  predicted-minus-realised gap as evidence of dropout, and explains that
  predictions use each respondent’s inferred route and loop counts.
- The scoring vignette now lists the automatic rule for every question
  type and which
  [`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
  entries each uses. Nine Table 1 entries (`rank_per_item`,
  `open_medium`, `please_specify`, `open_essay_per_extra`, `filter`,
  `branching`, `sc_2_alt`, `sc_3_alt`, `sc_per_variable`) are reference
  only – no rule reads them, so changing them does not change scores;
  [`?gfs_scheme`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
  says so too. It also states that item scores are per iteration, that
  loop profiles run from 1 to the cap, and what can make the reported
  figures too low.
- The paths vignette has a runnable recipe for building `visit_*` and
  `loop_*` route columns from a response export, and for checking
  `matched` before summarising, with what a match does and does not
  certify.
  [`?respondent_burden`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
  and the vignette now state how `0`, `NA`, over-cap and non-logical
  values in route columns are read.
- The calibration vignette has a runnable
  [`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md)
  recipe: filtering non-finishers first, naming the duration column
  (Qualtrics’ `Duration (in seconds)` is not recognised), adding route
  columns, choosing and reporting the trim, and how to read `ratio`,
  `cor` and `implied_points_per_minute`.
- The extensions vignette and README no longer say downstream functions
  work “unchanged” on any catalogue. They now separate what works now
  ([`score_burden()`](https://pmpk20.github.io/surveyBurden/reference/score_burden.md)
  on a catalogue), what needs an adapter
  ([`path_burden()`](https://pmpk20.github.io/surveyBurden/reference/path_burden.md)
  with a hand-built paths table, shown runnable) and what still needs a
  Qualtrics survey (profiles,
  [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md),
  respondent functions), and note that `has_display_logic = FALSE`
  removes conditionality rather than skipping the profile.
- New “Revising a survey to reduce burden” vignette: find the heaviest
  blocks and questions, check how they were scored, make a change,
  re-score and compare, and what the comparison does and does not
  establish. README and the get-started vignette open with a “where to
  start” table.
- Every guide now opens with what it answers, what you need and what it
  cannot establish, and ends with a “Next” section.
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
