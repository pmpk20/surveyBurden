# Ex-ante instrument burden report

The user-facing entry point. Parses a Qualtrics `.qsf`, resolves its
flow and display logic, scores every question with the GfS / Axhausen
scheme, and summarises the burden across the instrument's structural
path space.

## Usage

``` r
burden_report(
  x,
  weights = gfs_weights(),
  profile = TRUE,
  routes = NULL,
  rare_threshold = 1500,
  stem_warning_threshold = 40L,
  label_warning_threshold = 10L,
  words_per_line = NULL,
  certainty = TRUE,
  quiet = FALSE
)

# S3 method for class 'burden_report'
summary(object, ...)
```

## Arguments

- x:

  A path to a `.qsf` file, or a `qsf_raw` object from
  [`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md).

- weights:

  A
  [`gfs_weights()`](https://pmpk20.github.io/surveyBurden/reference/gfs_weights.md)
  list.

- profile:

  If `TRUE` (default), enumerate the display-logic structural burden
  profile
  ([`path_burden_profile()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_profile.md))
  to get the *achievable* min/median/ max burden for this survey – a few
  seconds of extra work. `FALSE` skips that and falls back to a much
  faster but naive range (see Details): min/max only, no median, and the
  numbers can understate the true minimum.

- routes:

  Optional respondent data frame (see
  [`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)).
  When supplied, the report adds a population-weighted burden summary:
  each route is weighted by how often respondents actually take it, so
  unlike the structural profile this is a real average over respondents.

- rare_threshold:

  GfS points above which Heimgartner & Axhausen (2024) found surveys to
  be rare (their sample: median 399, n = 79 waves). Used for the "rare
  burden" warning and to scale the `index` column of `$burden` to 0-1.

- stem_warning_threshold:

  Question stems longer than this many words are flagged in the
  readability diagnostics (default 40). Diagnostic only – this does
  **not** change any GfS score.

- label_warning_threshold:

  For matrix/grid questions, response-option or row labels longer than
  this many words are flagged (default 10). Diagnostic only.

- words_per_line:

  Optional override for the descriptive-text "lines" conversion (default
  12, from
  [`gfs_weights()`](https://pmpk20.github.io/surveyBurden/reference/gfs_weights.md)).
  This is a pragmatic conversion heuristic – GfS scores instruction text
  in rendered lines, and a QSF has words, not a rendered width – not an
  empirically calibrated constant. Set it to your survey theme's typical
  line length if you have one.

- certainty:

  If `TRUE` (default), attach and print the
  [`calculation_certainty()`](https://pmpk20.github.io/surveyBurden/reference/calculation_certainty.md)
  breakdown. `FALSE` skips it (a little faster).

- quiet:

  If `FALSE` (default), report progress through the pipeline stages with
  [`cli::cli_progress_step()`](https://cli.r-lib.org/reference/cli_progress_step.html).
  `TRUE` silences it.

- object:

  A `burden_report` from `burden_report()`.

- ...:

  Not used.

## Value

An object of class `burden_report`: a list of tibbles under stable
names. Print it for the formatted summary, or read its components:

- instrument:

  One-row tibble of structural counts: `survey_name`, `n_questions`,
  `n_blocks`, `n_branches`, `n_randomisers`, `n_loop_blocks`,
  `n_end_points`, `n_paths`, `n_complete_paths`, `n_screenout_paths`.

- burden:

  Five-row tibble, one row per statistic (`min`, `p25`, `median`, `p75`,
  `max`), with `points`, `minutes` (points per minute from
  [`gfs_weights()`](https://pmpk20.github.io/surveyBurden/reference/gfs_weights.md))
  and `index` (`points / rare_threshold`). `attr(, "basis")` is
  `"structural"` when `profile = TRUE`, else `"naive"` and only `min` /
  `max` are populated.

- blocks:

  One row per block, in survey order: `block_id`, `block_name`,
  `flow_order`, `n_questions`, `gfs_points` and `share` (share of
  all-question points).

- items:

  The full
  [`score_burden()`](https://pmpk20.github.io/surveyBurden/reference/score_burden.md)
  table, every live question with its `gfs_points`, `score_flag` and
  `score_basis`.

- paths:

  One row per structural path: `path_id`, `status` (factor `complete` /
  `screen_out`), `n_blocks`, `n_questions_floor`, `n_questions_ceiling`,
  `burden_floor`, `burden_ceiling`, `n_gates`, and `burden_min` /
  `burden_median` / `burden_max` (`NA` when `profile = FALSE`).

- readability:

  Diagnostic, not part of the GfS score: `stem_threshold`,
  `label_threshold`, and the tibbles `long_stems`, `long_labels` and
  `long_grids`.

- certainty:

  [`calculation_certainty()`](https://pmpk20.github.io/surveyBurden/reference/calculation_certainty.md)
  output, or `NULL` when `certainty = FALSE`.

- warnings:

  Character vector of QC flags, in plain language.

- population:

  Present only when `routes` is supplied: a tibble the same shape as
  `burden`, weighted by observed respondent routes.

Scalars are attributes: `points_per_minute`, `rare_threshold`,
`benchmark` (`list(median_points, n_waves)`) and `profile_used`.

## Details

**Why two ranges exist.**
[`path_burden()`](https://pmpk20.github.io/surveyBurden/reference/path_burden.md)
(the fast, naive check) scores each flow path by assuming every optional
(display-logic-gated) question can be independently hidden for the
minimum, or independently shown for the maximum. That assumption is not
always achievable: some questions are gated by conditions that are
satisfied by default (e.g. "shown unless a specific answer was picked"),
so they cannot actually be hidden regardless of what else the respondent
answers.
[`path_burden_profile()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_profile.md)
enumerates the real display-logic combinations and finds the burden
values that are genuinely reachable, which is why its minimum is usually
*higher* than the naive floor. **This report uses the profile's range as
the one range shown, whenever `profile = TRUE`.**

## Examples

``` r
if (FALSE) { # \dontrun{
br <- burden_report("survey.qsf")
br                       # formatted summary
summary(br)              # short headline
br$burden                # the min/median/max table
br$items[order(-br$items$gfs_points), ]   # questions by burden
br$paths
} # }
```
