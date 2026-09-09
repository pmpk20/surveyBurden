# Assessing survey burden with surveyBurden

``` r

library(surveyBurden)
demo <- system.file("extdata", "demo_travel_survey.qsf", package = "surveyBurden")
```

This vignette is both a user guide and a short methodological
specification. Every code chunk below runs against the small fictional
“Neighbourhood Travel Survey” that ships with the package, so the
numbers shown are the numbers the current package produces. To use your
own survey, replace `demo` with a path to a `.qsf` file, a bare `SV_...`
survey id, or a Qualtrics survey-builder URL.

A few chunks show patterns the vignette cannot run here, such as a live
API fetch or a calibration against your own completion times. Those are
marked as illustrative and are not evaluated.

## 1. Overview

`surveyBurden` estimates **ex-ante instrument burden**: the response
effort a programmed survey instrument demands, worked out before
fielding from the instrument alone. In the terms of Yan and Williams
(2022) this is the *instrument* side of respondent burden, that is
length, difficulty, and the effort the design requires. It is not the
*perceived* burden a particular respondent reports feeling, which also
depends on topic salience, motivation, and context.

The package reads a Qualtrics survey, scores every question with the
published GfS / Axhausen point scheme, reconstructs the routes the flow
and display logic allow, and reports how burden varies across those
routes.

Six terms are used throughout, with fixed meanings:

| term | meaning |
|----|----|
| **question burden** | the GfS point score for one question, from its type and structure |
| **path burden** | the total question burden along one structural path through the survey flow |
| **structural burden profile** | the set of feasible burden values across a path’s display-logic sub-states, each counted once. Not a probability distribution. |
| **population-weighted respondent burden** | burden averaged over real respondent routes, where route frequencies stand in for the sub-state probabilities. Produced only when `routes` are supplied. |
| **calculation certainty** | the split, for a given survey, between parts of the calculation that are exact and parts that rest on documented approximations |
| **readability diagnostics** | counts of long question stems, long matrix labels, and long grids. Reading-load signals, reported separately, never folded into the GfS score. |

**What the package is not.** It is not a new theory of respondent
burden. It is not a measure of perceived burden. It is not a
completion-time predictor: it converts points to minutes only through a
published rule of thumb, described in section 12. It is not a
stated-choice or discrete choice burden model.

One call runs the whole pipeline.

``` r

report <- burden_report(demo)
#> ℹ Reading survey
#> ✔ Reading survey [24ms]
#> 
#> ℹ Scoring questions and resolving paths
#> ✔ Scoring questions and resolving paths [252ms]
#> 
#> ℹ Checking calculation certainty
#> ✔ Checking calculation certainty [33ms]
#> 
#> ℹ Enumerating display-logic combinations
#> ✔ Enumerating display-logic combinations [27ms]
#> 
report
#> 
#> ── Survey Burden Report: Neighbourhood Travel Survey (demo) ────────────────────
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
#> Display-logic combinations checked: 3-4 per complete path
#> 
#> ── Burden (12 GfS points ~ 1 minute; index = points / 1500) ──
#> 
#> Statistic        Points  ~Min  Index
#> ------------------------------------
#> Minimum             106     9   0.07
#> 25th percentile     117    10   0.08
#> Median              123    10   0.08
#> 75th percentile     129    11   0.09
#> Maximum             143    12   0.10
#> Benchmark: median 399 points across 79 GfS-scored survey waves (Heimgartner &
#> Axhausen 2024).
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
#> ── Readability diagnostics (reading load; not part of the GfS score) ──
#> 
#> Long stems (> 40 words)          0
#> Long matrix labels (> 10 words)  0
#> Long grids (> 6 rows)            1
#> 
#> ── Calculation certainty ──
#> 
#> Paths: 0/2 resolve exactly; 2 carry an unresolved display-logic condition.
#> Display logic: 6/6 conditional questions enumerated exactly, 0 approximated.
#> Loops: 2 with a known cap, 0 unknown.  Item scores: 19 auto / 7 inferred / 0
#> manual.
#> 
#> ── QC warnings (3) ──
#> 
#> ! 1 matrix/grid question has more than 6 rows. Long grids invite satisficing (respondents picking the same answer down the column instead of reading each row): QID19
#> ! 2 of 4 structural paths are screen-outs (the survey ends early there) rather than complete responses.
#> ! The point range above comes from checking every combination of optional questions this survey's skip logic could show. Each combination is counted once; we have no data on how likely each one is for a given respondent, so this is a structural range, not a probability -- it does NOT mean "there's a 50% chance a respondent sees the median burden".
```

The bundled demo is deliberately small. On a fielded instrument these
counts run to hundreds of questions and dozens of paths. The rest of
this vignette explains each part of that output.

## 2. Input and parsing

[`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md)
accepts a path to a `.qsf` export, a bare `SV_...` survey id, or a
survey-builder URL. A path is read locally. An id or URL is fetched
through the Qualtrics API by
[`fetch_qsf()`](https://pmpk20.github.io/surveyBurden/reference/fetch_qsf.md),
which needs `QUALTRICS_API_KEY` and `QUALTRICS_BASE_URL` in the
environment. All three inputs normalise to one internal representation
of class `qsf_raw`, so nothing downstream depends on where the survey
came from.

``` r

qsf <- read_qsf(demo)
class(qsf)
#> [1] "qsf_raw"
```

[`parse_qsf()`](https://pmpk20.github.io/surveyBurden/reference/parse_qsf.md)
turns that representation into a question catalogue: one row per live
question, with the structural facts the scorer needs.

``` r

catalogue <- parse_qsf(qsf)
nrow(catalogue)
#> [1] 26
names(catalogue)
#>  [1] "question_id"        "flow_order"         "block_id"          
#>  [4] "block_name"         "std_type"           "qualtrics_type"    
#>  [7] "selector"           "subselector"        "n_options"         
#> [10] "n_rows"             "n_cols"             "text_words"        
#> [13] "max_label_words"    "label_text"         "options_numeric"   
#> [16] "question_text"      "is_hidden"          "has_display_logic" 
#> [19] "display_logic_refs" "has_validation"     "in_loop"           
#> [22] "loop_max"           "flag"
```

The API-fetch pattern looks like this. It is not run here.

``` r

Sys.setenv(
  QUALTRICS_API_KEY  = "your-api-key",
  QUALTRICS_BASE_URL = "https://yourdatacenter.qualtrics.com"
)
report <- burden_report(
  "https://yourorg.qualtrics.com/survey-builder/SV_xxxxxxxxxxxxxxxx/edit"
)
```

`QUALTRICS_BASE_URL` is the API datacenter host, found under Account
Settings then Qualtrics IDs. It can differ from your survey-builder
host. The fetch is checked against live surveys to return the same
result as the corresponding `.qsf` export.

## 3. Question classification

[`classify_question()`](https://pmpk20.github.io/surveyBurden/reference/classify_question.md)
maps each Qualtrics widget to a standard question type. The Qualtrics
type alone is not enough: a single `MC` widget can be a yes/no item, a
rating scale, a dropdown, or a multi-select, depending on its selector
and options. Classification resolves that.

``` r

table(catalogue$std_type)
#> 
#>   descriptive        matrix  multi_choice     open_text single_choice 
#>             1             4             1             3            17
```

For the demo this is 17 single-choice questions, 4 matrix questions, 3
open-text questions, 1 multi-select, and 1 descriptive text block. The
`std_type` column drives scoring in the next section.

## 4. GfS scoring

[`gfs_weights()`](https://pmpk20.github.io/surveyBurden/reference/gfs_weights.md)
holds the GfS / Axhausen point weights (Heimgartner and Axhausen 2024,
Table 1) transcribed verbatim, one weight per response action, plus a
points-per-minute conversion. No weights are invented.

``` r

w <- gfs_weights()
w$yes_no
#> [1] 1
w$rating_small
#> [1] 2
w$rating_large
#> [1] 3
w$points_per_minute
#> [1] 12
```

[`score_burden()`](https://pmpk20.github.io/surveyBurden/reference/score_burden.md)
then works in **three layers**:

1.  what Qualtrics says the widget is (for example `MC` with a dropdown
    selector);
2.  what response action that implies (for example choose one value from
    an ordered list);
3.  which Table 1 category best represents that action (for example a
    rating).

Where step 3 is fixed by the structure, for example a two-option choice
is a closed yes/no item whatever it asks, the mapping is deterministic
and the score is marked `auto`. Where the `.qsf` does not carry what the
scheme needs, the package applies an **explicit, documented inference
rule** and marks the item `inferred`. Every scored question carries a
`score_basis` string that records the rule applied.

`score_flag` has four values:

- `auto`: the GfS mapping is deterministic from the structure.
- `inferred`: the structure is clear, but choosing the Table 1 category
  involved an explicit judgement, for example a dropdown mapped to
  “rating” as the closest category, a numeric-looking dropdown mapped to
  “simple numerical answer”, or a slider. The number is still
  determinate.
- `manual`: a human should check; the mapping is genuinely uncertain.
- `unknown`: an unmapped type, left unscored as `NA`.

``` r

scored <- score_burden(catalogue, weights = w)
table(scored$score_flag)
#> 
#>     auto inferred 
#>       19        7
head(scored[order(-scored$gfs_points),
            c("question_id", "std_type", "gfs_points", "score_flag", "score_basis")])
#> # A tibble: 6 × 5
#>   question_id std_type     gfs_points score_flag score_basis                    
#>   <chr>       <chr>             <dbl> <chr>      <chr>                          
#> 1 QID21       matrix               18 auto       matrix, 6 rows x GfS rating >5…
#> 2 QID19       matrix               14 auto       matrix, 7 rows x GfS rating <=…
#> 3 QID14       multi_choice         12 auto       multi-select, 6 options -> GfS…
#> 4 QID20       matrix               12 auto       matrix, 6 rows x GfS rating <=…
#> 5 QID1        descriptive          11 inferred   transition/instruction text: 1…
#> 6 QID7        matrix                8 auto       matrix, 4 rows x GfS rating <=…
```

This is the distinction between **GfS-native** quantities, that is
question type, response action, and number of alternatives, all
specified by the scheme, and **package-derived** ones, that is estimated
line counts and response-unit structure, inferred because the `.qsf`
lacks them.

### Documented inference rules where Table 1 is silent

- Table 1 counts rendered “lines” of instruction text. A `.qsf` stores
  words, not a rendered width, so lines are estimated as words /
  `words_per_line` (default 12). This is a pragmatic conversion
  heuristic, not a calibrated constant; override it with
  `burden_report(words_per_line = ...)`. Section 11 states this
  assumption in full.
- Dropdowns (`MC` with a `DL` selector) have no Table 1 row. They are
  scored as a rating (2.0 for up to 5 options, 3.0 for more), or as a
  simple numerical answer (1.0) when the options are numbers and the
  question asks for a quantity or a date.
- Sliders are not in Table 1. They are scored as a numerical answer when
  the axis label carries units, otherwise as a rating.
- A question hidden from the respondent by injected CSS or JavaScript
  scores 0.
- Loop and Merge blocks are scored per iteration and multiplied by the
  block’s explicit iteration cap. Within-loop display logic is not
  enumerated.

### 4a. Question stems are not separately scored

Table 1’s “question or transition, up to 3 lines = 2.0” is applied to
standalone instruction blocks only. It is not added on top of every
question’s response score. The GfS scheme may intend the reading cost of
a question stem to be absorbed into the item weight; settling that needs
the underlying GfS methodology, not Table 1 alone. A question with a
long disambiguation stem is therefore scored conservatively, and its
stem length is reported separately as a readability diagnostic (section
11).

### 4b. Multi-answer matrices have no Table 1 rule

A grid where each cell allows multiple answers, that is “tick all that
apply” across two axes, is scored as `rows x cols x 0.5`. Each cell is
one trivial closed yes/no decision, and GfS scores a closed yes/no at
1.0, discounted here for the working-memory efficiency of answering in a
grid. This proxy is **orientation-invariant**: it is symmetric in rows
and columns, so unlike an earlier `rows x 4.0` proxy it does not change
with how Qualtrics happened to store the grid. It is a documented
inference, not GfS. The weight is `gfs_weights()$matrix_cell_multi`.

## 5. Survey flow

Contemporary web surveys are not a fixed sequence.
[`resolve_flow()`](https://pmpk20.github.io/surveyBurden/reference/resolve_flow.md)
walks the `SurveyFlow`, forking at every `Branch` into a condition-true
and a condition-false continuation, and at every `EndSurvey` into a
screen-out. Branch conditions are **not evaluated**, so both outcomes
are always kept. The result is every block sequence a respondent could
encounter.

``` r

resolve_flow(qsf)
#> # A tibble: 4 × 4
#>   path_id block_ids  terminates_early decisions
#>     <int> <list>     <lgl>            <list>   
#> 1       1 <chr [2]>  TRUE             <lgl [1]>
#> 2       2 <chr [3]>  TRUE             <lgl [2]>
#> 3       3 <chr [12]> FALSE            <lgl [3]>
#> 4       4 <chr [11]> FALSE            <lgl [3]>
```

The demo produces 4 structural paths: 2 that reach a real submission
(“complete”), and 2 that hit an `EndSurvey` first (“screen-out”). A
fielded instrument typically produces dozens.

## 6. Display logic

Within a path,
[`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md)
partitions the questions into three sets: **always shown**, **may be
shown** (gated by a condition that cannot be evaluated before fielding),
and **never shown on this path** (the gate’s trigger question is not on
the path).

``` r

rp <- resolve_paths(qsf)
data.frame(
  path_id      = rp$path_id,
  screen_out   = rp$terminates_early,
  n_always     = lengths(rp$q_always),
  n_maybe      = lengths(rp$q_maybe),
  n_gates      = rp$n_gates
)
#>   path_id screen_out n_always n_maybe n_gates
#> 1       1       TRUE        2       0       0
#> 2       2       TRUE        3       0       0
#> 3       3      FALSE       20       6       4
#> 4       4      FALSE       20       3       3
```

Qualtrics display logic is stored as `If` / `ElseIf` / `AndIf` groups.
The package folds each group left to right: `ElseIf` clauses are
combined with OR, `AndIf` clauses with AND. A group with a missing type
falls back to AND. This matters because flattening everything to AND
would under-count the cases where a question appears if any one of
several conditions holds.

## 7. Path enumeration

[`path_burden_profile()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_profile.md)
goes inside the “may be shown” set and enumerates the feasible
display-logic states.

- Conditional questions are grouped into **coupling components**. Two
  questions couple if they share a gate, directly or through a chain of
  gates.
- Small components are enumerated **exactly**: every joint state of
  their gates, respecting single-choice mutual exclusion and
  AND-across-gates conditions.
- Large components, for example dozens of questions keyed off one
  popular trigger such as employment status, fall back to a
  **primary-gate approximation** for that component: each question is
  scored against its first gate, and the rest are held permissive.
- Separate components are convolved as independent.
- Loop and Merge blocks are unrolled to the explicit `?v=N` cap, with
  the iteration count treated as uniform over 1 to N in the structural
  profile.

``` r

pbp <- path_burden_profile(qsf)
pbp[, c("path_id", "terminates_early", "burden_min", "burden_median", "burden_max")]
#> # A tibble: 4 × 5
#>   path_id terminates_early burden_min burden_median burden_max
#>     <int> <lgl>                 <dbl>         <dbl>      <dbl>
#> 1       1 TRUE                     12            12         12
#> 2       2 TRUE                     14            14         14
#> 3       3 FALSE                   106           124        143
#> 4       4 FALSE                   106           122        139
nrow(pbp$profile[[3]])  # feasible burden values on complete path 3
#> [1] 36
nrow(pbp$profile[[4]])  # feasible burden values on complete path 4
#> [1] 22
```

Each row of a `profile` table is one feasible burden value with a
structural weight from the gate combinatorics and the uniform
loop-iteration assumption. That weight is not a respondent probability.
Section 9 returns to this point.

## 8. Burden aggregation

`$burden` is built by pooling the per-path structural profiles for the
complete paths and taking order statistics across the pooled values.

``` r

report$burden
#> # A tibble: 5 × 4
#>   statistic points minutes  index
#>   <fct>      <dbl>   <dbl>  <dbl>
#> 1 min          106    8.83 0.0707
#> 2 p25          117    9.75 0.078 
#> 3 median       123   10.2  0.082 
#> 4 p75          129   10.8  0.086 
#> 5 max          143   11.9  0.0953
attr(report$burden, "basis")
#> [1] "structural"
```

- `points` is the GfS point total. `minutes` is `points` divided by the
  points-per-minute rate. `index` is `points / rare_threshold` (default
  1500), a 0 to 1 rescaling where 0 is a blank instrument and 1.0 is the
  level Heimgartner and Axhausen’s sample found rare.
- `attr(, "basis")` is `"structural"` when the display-logic profile was
  enumerated (the default), and `"naive"` when `profile = FALSE`. The
  naive band scores each optional question as independently hideable for
  the minimum and independently shown for the maximum. That is faster,
  but its minimum can fall below anything actually reachable, and it
  reports no median. The structural basis is the one to quote.
- The **benchmark** line under the printed table is the published GfS
  reference point: a median of 399 points across the 79 scored survey
  waves in Heimgartner and Axhausen (2024).

The per-path detail sits in `$paths`.

``` r

report$paths[, c("path_id", "status", "burden_floor", "burden_ceiling",
                 "burden_min", "burden_median", "burden_max")]
#> # A tibble: 4 × 7
#>   path_id status burden_floor burden_ceiling burden_min burden_median burden_max
#>     <int> <fct>         <dbl>          <dbl>      <dbl>         <dbl>      <dbl>
#> 1       1 scree…           12             12         12            12         12
#> 2       2 scree…           14             14         14            14         14
#> 3       3 compl…          103            145        106           124        143
#> 4       4 compl…          103            139        106           122        139
```

`burden_floor` and `burden_ceiling` are the naive per-path bounds.
`burden_min` / `burden_median` / `burden_max` are the structural profile
for that path, and are `NA` when `profile = FALSE`.

## 9. Structural versus population-weighted burden

This distinction is central and is easy to state wrongly.

The default result is a **structural burden profile**. It lists every
feasible combination of optional questions once. It carries no
respondent probabilities. When the report says the median is 123 points,
it means the median across those feasible combinations. It does **not**
mean that half of respondents face at least that much burden. Nobody has
told the package how common each combination is.

To get a real average over respondents you need observed routes. Give
[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
a data frame of respondents and it adds a **population-weighted
respondent burden**. In words: the average burden is the sum, over the
observed routes, of each route’s burden multiplied by how often that
route occurred. Writing the observed frequency of route k as w_k and its
burden as B_k:

``` math
\bar{B} = \sum_k w_k \, B_k
```

The structural profile is what you have without the w_k. The
population-weighted result is what the w_k buy you.

The recognised route columns are `loop_<id>` (the iteration count for a
Loop and Merge block, keyed by the driving question id or the block id)
and `visit_<block_id>` (`TRUE` to include a branch-gated optional
block). The demo has two loop blocks, `BL6` and `BL8`. Here is a small
constructed set of 50 respondent routes:

``` r

set.seed(1)
routes <- data.frame(
  loop_BL6 = rbinom(50, 5, 0.4),   # "Other adults" loop, cap 5
  loop_BL8 = rbinom(50, 3, 0.5)    # "Vehicle details" loop, cap 3
)
burden_report(demo, routes = routes)$population
#> ℹ Reading survey
#> ✔ Reading survey [8ms]
#> 
#> ℹ Scoring questions and resolving paths
#> ✔ Scoring questions and resolving paths [87ms]
#> 
#> ℹ Checking calculation certainty
#> ✔ Checking calculation certainty [22ms]
#> 
#> ℹ Enumerating display-logic combinations
#> ✔ Enumerating display-logic combinations [61ms]
#> 
#> # A tibble: 5 × 4
#>   statistic points minutes  index
#>   <fct>      <dbl>   <dbl>  <dbl>
#> 1 min         100     8.33 0.0667
#> 2 p25         110.    9.19 0.0735
#> 3 median      116     9.67 0.0773
#> 4 p75         122.   10.1  0.0812
#> 5 max         132    11    0.088
```

These numbers are weighted by the route frequencies in `routes`. Real
route data would come from a fielded response file, not from
[`rbinom()`](https://rdrr.io/r/stats/Binomial.html).

Without routes,
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
still gives a per-path table, and
[`summary_line()`](https://pmpk20.github.io/surveyBurden/reference/summary_line.md)
turns it into a sentence.

``` r

summary_line(respondent_burden(demo))
#> [1] "Typical respondent burden is about 118 GfS points (~10 min). The lightest complete route is ~117 pts (~10 min); with the Loop & Merge sections fully repeated it reaches ~143 pts (~12 min)."
```

## 10. Calculation certainty

[`calculation_certainty()`](https://pmpk20.github.io/surveyBurden/reference/calculation_certainty.md),
printed as the “Calculation certainty” block of the report, states for
your survey which parts of the calculation are exact and which rest on a
documented approximation.

``` r

report$certainty$paths[c("n_full", "n_exact", "n_with_unresolved")]
#> $n_full
#> [1] 2
#> 
#> $n_exact
#> [1] 0
#> 
#> $n_with_unresolved
#> [1] 2
report$certainty$display_logic[c("n_conditional", "n_exact", "n_approx",
                                 "n_components", "cross_component_independence")]
#> $n_conditional
#> [1] 6
#> 
#> $n_exact
#> [1] 6
#> 
#> $n_approx
#> [1] 0
#> 
#> $n_components
#> [1] 4
#> 
#> $cross_component_independence
#> [1] TRUE
report$certainty$loops[c("n_known", "n_unknown")]
#> $n_known
#> [1] 2
#> 
#> $n_unknown
#> [1] 0
report$certainty$scores
#> $auto
#> [1] 19
#> 
#> $inferred
#> [1] 7
#> 
#> $manual
#> [1] 0
#> 
#> $unknown
#> [1] 0
```

For the demo: neither complete path resolves to a single burden value,
because both carry an unresolved display-logic condition; all 6
conditional questions are enumerated exactly, none by the primary-gate
approximation; both loop blocks have a known cap; and of the 26 item
scores, 19 are `auto` and 7 are `inferred`, with none needing manual
review.

The reader should take away one thing: a result can be fully
reproducible without every underlying interpretation being certain. The
certainty block makes the uncertain parts countable.

## 11. Readability diagnostics

`$readability` reports three counts: `long_stems` (question stems over
`stem_threshold` words, default 40), `long_labels` (matrix row or option
labels over `label_threshold` words, default 10), and `long_grids`
(matrix questions with more than 6 rows).

``` r

report$readability$stem_threshold
#> [1] 40
report$readability$label_threshold
#> [1] 10
nrow(report$readability$long_stems)
#> [1] 0
nrow(report$readability$long_labels)
#> [1] 0
report$readability$long_grids[, c("question_id", "block_name", "n_rows")]
#> # A tibble: 1 × 3
#>   question_id block_name n_rows
#>   <chr>       <chr>       <int>
#> 1 QID19       Travel          7
```

These are reading-load signals. **None of them changes any GfS score.**
They are reported separately so that a long grid or a wordy stem is
visible without being silently priced into the burden total.

The `words_per_line` assumption behind the descriptive-text score
deserves a plain statement. GfS refers to rendered lines of text. A
`.qsf` stores words, not the width the respondent’s browser will render
them at. The package therefore approximates lines as words divided by a
configurable words-per-line figure (default 12). It is a practical
proxy, not a calibration, and it is the reason the descriptive-text
score for a long instruction block should be read as approximate.

## 12. Limitations

- The Qualtrics-to-GfS mapping is sometimes inferential. Where a widget
  has no exact match in Table 1, the package applies a documented rule
  and flags the question `inferred`.
- The GfS scheme predates modern web survey interfaces. It was
  calibrated on earlier survey practice.
- Rendered text length cannot be recovered from a `.qsf`. The file
  stores words, not an on-screen line count.
- `words_per_line` is a configurable proxy for that missing line count,
  not a measured constant.
- Display-logic reconstruction depends on what the `.qsf` encodes. Logic
  controlled outside Qualtrics, or unusual constructs, may need manual
  interpretation.
- Structural enumeration gives no respondent probabilities. Without
  route data, every feasible combination is counted once, and “median”
  means the median across combinations, not across respondents.
- Loop and Merge can make the path space large. The package unrolls to
  the explicit cap and treats the iteration count as uniform.
- The points-to-minutes conversion is the published GfS rule of thumb,
  roughly 12 points per minute. It is a scale, not a completion-time
  prediction. Set a survey-specific figure with
  [`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md)
  on your own completion-time data. This is not run here; it needs a
  completion-time file the package does not ship:

``` r

w <- gfs_weights()
w$points_per_minute <- validate_times(demo, "times.csv")$implied_points_per_minute
burden_report(demo, weights = w)
```

- Burden scores are not predictions of completion time, dropout, or
  satisficing. Those are empirical questions about respondent behaviour,
  outside the scope of this package.

## 13. Reproducible worked example

One end-to-end pass on the bundled demo. This runs on a clean install
with no private files.

``` r

report <- burden_report(demo)
#> ℹ Reading survey
#> ✔ Reading survey [8ms]
#> 
#> ℹ Scoring questions and resolving paths
#> ✔ Scoring questions and resolving paths [89ms]
#> 
#> ℹ Checking calculation certainty
#> ✔ Checking calculation certainty [23ms]
#> 
#> ℹ Enumerating display-logic combinations
#> ✔ Enumerating display-logic combinations [31ms]
#> 
summary(report)
#> 
#> ── Neighbourhood Travel Survey (demo) ──────────────────────────────────────────
#> 26 questions, 12 blocks, 4 structural paths (2 complete).
#> Burden: 106 / 123 / 143 points (min / median / max; ~9 / 10 / 12 min).
#> Benchmark: median 399 points across 79 GfS-scored waves.
```

The headline: 26 questions across 12 blocks, 4 structural paths of which
2 are complete, and a structural burden spread of 106 / 123 / 143
points, well below the 399-point GfS benchmark.

``` r

report$burden
#> # A tibble: 5 × 4
#>   statistic points minutes  index
#>   <fct>      <dbl>   <dbl>  <dbl>
#> 1 min          106    8.83 0.0707
#> 2 p25          117    9.75 0.078 
#> 3 median       123   10.2  0.082 
#> 4 p75          129   10.8  0.086 
#> 5 max          143   11.9  0.0953
```

The spread from minimum to maximum is the effect of the survey’s
optional questions and loop iterations, not measurement noise.

``` r

report$paths[, c("path_id", "status", "n_questions_floor",
                 "n_questions_ceiling", "burden_min", "burden_max")]
#> # A tibble: 4 × 6
#>   path_id status     n_questions_floor n_questions_ceiling burden_min burden_max
#>     <int> <fct>                  <int>               <int>      <dbl>      <dbl>
#> 1       1 screen_out                 2                   2         12         12
#> 2       2 screen_out                 3                   3         14         14
#> 3       3 complete                  20                  26        106        143
#> 4       4 complete                  20                  23        106        139
```

Path 1 and path 2 are screen-outs worth 12 and 14 points. The two
complete paths differ mainly in one branch-gated block.

``` r

report$items[order(-report$items$gfs_points),
             c("question_id", "block_name", "std_type", "n_rows", "n_cols",
               "n_options", "gfs_points", "score_flag")]
#> # A tibble: 26 × 8
#>    question_id block_name std_type n_rows n_cols n_options gfs_points score_flag
#>    <chr>       <chr>      <chr>     <int>  <int>     <int>      <dbl> <chr>     
#>  1 QID21       Attitudes  matrix        6      7        NA         18 auto      
#>  2 QID19       Travel     matrix        7      4        NA         14 auto      
#>  3 QID14       Vehicles   multi_c…     NA     NA         6         12 auto      
#>  4 QID20       Travel     matrix        6      4        NA         12 auto      
#>  5 QID1        Welcome    descrip…     NA     NA         0         11 inferred  
#>  6 QID7        About you  matrix        4      3        NA          8 auto      
#>  7 QID25       Closing    open_te…     NA     NA         0          6 auto      
#>  8 QID6        About you  single_…     NA     NA         6          3 auto      
#>  9 QID11       Other adu… single_…     NA     NA         6          3 auto      
#> 10 QID16       Vehicle d… single_…     NA     NA         6          3 auto      
#> # ℹ 16 more rows
```

The heaviest questions are the attitude and frequency matrices. The
`score_flag` column shows which scores are deterministic (`auto`) and
which rest on a documented inference (`inferred`); `score_basis` in the
same table records the exact rule for each.

## References

- Heimgartner, D. and Axhausen, K. W. (2024). Predicting response rates
  once again. *Findings*.
  <https://findingspress.org/article/125481-predicting-response-rates-once-again>
- Schmid, B. and Axhausen, K. W. (2019). In-store or online grocery
  shopping before and during the COVID-19 pandemic.
- Yan, T. and Williams, D. (2022). Response burden: a review and
  conceptual framework. *Journal of Official Statistics*.
- Yan, T. and Tourangeau, R. (2008). Fast times and easy questions: the
  effects of age, experience, and question complexity on web survey
  response times. *Applied Cognitive Psychology*.
