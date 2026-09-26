# Ex-ante instrument burden report

The user-facing entry point. Parses a Qualtrics `.qsf`, resolves its
flow and display logic, scores every question with the GfS+ burden-point
scheme (extending Heimgartner and Axhausen 2024,
[doi:10.32866/001c.125481](https://doi.org/10.32866/001c.125481) ), and
summarises the burden across the instrument's structural path space.

## Usage

``` r
burden_report(
  x,
  scheme = gfs_scheme(),
  profile = TRUE,
  routes = NULL,
  rare_threshold = 1500,
  stem_warning_threshold = 40L,
  label_warning_threshold = 10L,
  words_per_line = NULL,
  max_paths = 10000L,
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

- scheme:

  A
  [`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
  list.

- profile:

  If `TRUE` (default), enumerate the display-logic structural burden
  profile
  ([`path_burden_profile()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_profile.md))
  to get the min/median/max burden over the display-logic states the
  package can model for this survey – a few seconds of extra work.
  `FALSE` skips that and falls back to a much faster but naive range
  (see Details): min/max only, no median, and the numbers can understate
  the true minimum.

- routes:

  Optional respondent data frame (see
  [`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)).
  When supplied, the report adds `$population`: quantiles and the mean
  of one predicted burden per respondent, so each route counts as often
  as respondents took it. Unlike the structural profile, this summarises
  observed respondents.

- rare_threshold:

  GfS+ points above which Heimgartner & Axhausen (2024) found surveys to
  be rare (their sample: median 399, n = 79 waves). Used for the "rare
  burden" warning and to scale the `index` column of `$burden`
  (`points / rare_threshold`: 1 is the threshold, and it can exceed 1).

- stem_warning_threshold:

  Question stems longer than this many words are flagged in the
  readability diagnostics (default 40). Diagnostic only – this does
  **not** change any GfS+ score.

- label_warning_threshold:

  For matrix/grid questions, response-option or row labels longer than
  this many words are flagged (default 10). Diagnostic only.

- words_per_line:

  Optional override for the descriptive-text "lines" conversion (default
  12, from
  [`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)).
  This is a pragmatic conversion heuristic – GfS scores instruction text
  in rendered lines, and a QSF has words, not a rendered width – not an
  empirically calibrated constant. Set it to your survey theme's typical
  line length if you have one.

- max_paths:

  Cap on the number of distinct structural paths to enumerate (default
  10 000). Passed to
  [`resolve_flow()`](https://pmpk20.github.io/surveyBurden/reference/resolve_flow.md).
  Surveys with heavily branching flows may exceed this; raise the cap or
  treat the error as a diagnostic finding (intractable routing).

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
  [`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md))
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

  Diagnostic, not part of the GfS+ score: `stem_threshold`,
  `label_threshold`, and the tibbles `long_stems`, `long_labels` and
  `long_grids`.

- certainty:

  [`calculation_certainty()`](https://pmpk20.github.io/surveyBurden/reference/calculation_certainty.md)
  output, or `NULL` when `certainty = FALSE`.

- warnings:

  Character vector of QC flags, in plain language.

- population:

  Present only when `routes` is supplied: an eight-row tibble with the
  same columns as `burden`, summarising per-respondent predictions as
  `min`, `p10`, `p25`, `median`, `mean`, `p75`, `p90`, `max`. Each
  respondent has equal weight. Quantiles use
  [`stats::quantile()`](https://rdrr.io/r/stats/quantile.html) with its
  default `type = 7`; `mean` is the arithmetic mean. Missing predictions
  are excluded; all statistics are `NA` when no non-missing predictions
  are available.

Scalars are attributes: `points_per_minute`, `rare_threshold`,
`benchmark` (`list(median_points, n_waves)`) and `profile_used`.

## Details

**Why two ranges exist.**
[`path_burden()`](https://pmpk20.github.io/surveyBurden/reference/path_burden.md)
(the fast, naive check) scores each flow path by assuming every optional
(display-logic-gated) question can be independently hidden for the
minimum, or independently shown for the maximum. That assumption does
not always hold: some questions are gated by conditions that are
satisfied by default (e.g. "shown unless a specific answer was picked"),
so they cannot actually be hidden regardless of what else the respondent
answers.
[`path_burden_profile()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_profile.md)
enumerates the display-logic combinations the package can model and
finds the burden values they produce, which is why its minimum is
usually *higher* than the naive floor. Branch conditions are not checked
against each other, so these extremes are not guaranteed to be reachable
by a real respondent. **This report uses the profile's range as the one
range shown, whenever `profile = TRUE`.**

**Path-space cap.** The structural path space is enumerated up to
`max_paths` (default 10 000). A flow that would produce more raises an
error rather than a partial answer; raise `max_paths` or treat it as a
diagnostic finding (intractable routing). Block randomisers are treated
as "all sub-blocks shown, in survey order" – the randomised subsets are
not enumerated.

## Examples

``` r
# \donttest{
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                         package = "surveyBurden")
br <- burden_report(qsf_path)
#> ℹ Reading survey
#> ✔ Reading survey [9ms]
#> 
#> ℹ Scoring questions and resolving paths
#> ✔ Scoring questions and resolving paths [114ms]
#> 
#> ℹ Checking calculation certainty
#> ✔ Checking calculation certainty [30ms]
#> 
#> ℹ Enumerating display-logic combinations
#> ✔ Enumerating display-logic combinations [24ms]
#> 
br
#> 
#> ── Survey Burden Report: Neighbourhood Travel Survey (demo) ────────────────────
#> Median completing path: 123 GfS+ points, ~10 min - 0.3x the benchmark median of
#> 399. Path burden ranges 106-143 points (9-12 min) across 2 completing paths.
#> 
#> ── Instrument ──
#> 
#> Questions (live)     26
#> Blocks               12
#> Branch points         3
#> Randomisers           0
#> Loop & Merge blocks   2
#> Early-exit points     2
#> 
#> ── Paths ──
#> 
#> Structural paths: 4 (2 complete, 2 screen-out)
#> Display-logic trigger questions: 3-4 per complete path
#> 
#> ── Burden (12 GfS+ points ~ 1 minute; index = points / 1500) ──
#> 
#> Statistic        Points  ~Min  Index
#> ------------------------------------
#> Minimum             106     9   0.07
#> 25th percentile     117    10   0.08
#> Median              123    10   0.08
#> 75th percentile     129    11   0.09
#> Maximum             143    12   0.10
#> Benchmark: median 399 points across 79 GfS-scored waves (Heimgartner & Axhausen
#> 2024).
#> 
#> ── Burden by block (survey order; share of all-question points) ──
#> 
#> Welcome                   10%  ###
#> Consent                    1%  #
#> Area check                 2%  #
#> About you                 13%  ####
#> Household                  3%  #
#> Other adults               4%  #
#> Vehicles                  12%  ###
#> Vehicle details            5%  ##
#> Travel                    23%  #######
#> Attitudes                 16%  #####
#> Commuting                  5%  ##
#> Closing                    6%  ##
#> 
#> ── Highest-burden questions ──
#> 
#> QID21      18 pts  6x7      How much do you agree with each statement?
#> QID19      14 pts  7x4      In the past month, how often did you use each of these?
#> QID14      12 pts  6 opt    Which of these does your household own or have use of? ...
#> QID20      12 pts  6x4      And for each of these reasons for travelling, how often...
#> QID1       11 pts  0 opt    Welcome, and thank you for taking part in the Neighbour...
#> QID7        8 pts  4x3      For each area, do you have a condition that makes trave...
#> 
#> ── Readability diagnostics (reading load; not part of the GfS+ score) ──
#> 
#> Long stems (> 40 words)          0
#> Long matrix labels (> 10 words)  0
#> Long grids (> 6 rows)            1
#> 
#> ── Calculation certainty ──
#> 
#> Paths: 0/2 have no unresolved display-logic question; 2 carry at least one.
#> Display logic: 6/6 conditional questions enumerated in full within the model, 0
#> approximated.
#> Loops: 2 with a known cap, 0 unknown.  Item scores: 19 auto / 7 inferred / 0
#> manual.
#> 
#> ── QC warnings (3) ──
#> 
#> ! 1 matrix/grid question has more than 6 rows. Long grids invite satisficing (respondents picking the same answer down the column instead of reading each row): QID19
#> ! 2 of 4 structural paths are screen-outs (the survey ends early there) rather than complete responses.
#> ! The point range above comes from the combinations of optional questions the package can model for this survey's flow and skip logic. Each complete path carries equal weight, and so does each modelled combination within a path; these are model weights, not how often respondents see each one, so this is a structural range, not a probability -- it does NOT mean "there's a 50% chance a respondent sees the median burden".
summary(br)
#> 
#> ── Neighbourhood Travel Survey (demo) ──────────────────────────────────────────
#> 26 questions, 12 blocks, 4 structural paths (2 complete).
#> Median completing path: 123 GfS+ points, ~10 min - 0.3x the benchmark median of
#> 399. Path burden ranges 106-143 points (9-12 min) across 2 completing paths.
#> Benchmark: median 399 points across 79 GfS-scored waves.
br$burden
#> # A tibble: 5 × 4
#>   statistic points minutes  index
#>   <fct>      <dbl>   <dbl>  <dbl>
#> 1 min          106    8.83 0.0707
#> 2 p25          117    9.75 0.078 
#> 3 median       123   10.2  0.082 
#> 4 p75          129   10.8  0.086 
#> 5 max          143   11.9  0.0953
br$items[order(-br$items$gfs_points), ]
#> # A tibble: 26 × 30
#>    question_id block_id block_name question_text std_type selector n_rows n_cols
#>    <chr>       <chr>    <chr>      <chr>         <chr>    <chr>     <int>  <int>
#>  1 QID21       BL10     Attitudes  How much do … matrix   Likert        6      7
#>  2 QID19       BL9      Travel     In the past … matrix   Likert        7      4
#>  3 QID14       BL7      Vehicles   Which of the… multi_c… MAVR         NA     NA
#>  4 QID20       BL9      Travel     And for each… matrix   Likert        6      4
#>  5 QID1        BL1      Welcome    Welcome, and… descrip… TB           NA     NA
#>  6 QID7        BL4      About you  For each are… matrix   Likert        4      3
#>  7 QID25       BL12     Closing    Is there any… open_te… ML           NA     NA
#>  8 QID6        BL4      About you  Which best d… single_… SAVR         NA     NA
#>  9 QID11       BL6      Other adu… What is this… single_… SAVR         NA     NA
#> 10 QID16       BL8      Vehicle d… What type of… single_… SAVR         NA     NA
#> # ℹ 16 more rows
#> # ℹ 22 more variables: n_options <int>, gfs_points <dbl>, est_seconds <dbl>,
#> #   score_flag <chr>, score_basis <chr>, text_words <int>,
#> #   max_label_words <int>, has_display_logic <lgl>, loop_max <int>,
#> #   flow_order <int>, qualtrics_type <chr>, subselector <chr>,
#> #   is_dropdown <lgl>, is_multiline <lgl>, is_multi_answer <lgl>,
#> #   label_text <chr>, options_numeric <lgl>, is_hidden <lgl>, …
# }
```
