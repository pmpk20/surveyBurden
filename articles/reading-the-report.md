# Reading the burden report

This article walks the printed
[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
output section by section: what each shows, how to read it, and when it
is telling you something is wrong. For how the underlying numbers are
produced see
[`vignette("gfs-scoring")`](https://pmpk20.github.io/surveyBurden/articles/gfs-scoring.md)
and
[`vignette("paths-and-display-logic")`](https://pmpk20.github.io/surveyBurden/articles/paths-and-display-logic.md).

``` r

library(surveyBurden)
demo <- system.file("extdata", "demo_travel_survey.qsf", package = "surveyBurden")
report <- burden_report(demo, quiet = TRUE)
report
#> 
#> ── Survey Burden Report: Neighbourhood Travel Survey (demo) ────────────────────
#> Median completing path: 123 GfS points, ~10 min - 0.3x the benchmark median of
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

## The verdict line

The first line under the title is a plain-language summary: the median
completing-path burden in GfS points and in minutes, its ratio to the
399-point GfS benchmark, and the point range across the survey’s
completing paths. When you supply `routes` it also reports the
population-weighted median (see
[`vignette("paths-and-display-logic")`](https://pmpk20.github.io/surveyBurden/articles/paths-and-display-logic.md)).

`summary(report)` prints the same verdict with the structural counts and
nothing else.

## Instrument

``` r

report$instrument
#> # A tibble: 1 × 10
#>   survey_name        n_questions n_blocks n_branches n_randomisers n_loop_blocks
#>   <chr>                    <int>    <int>      <int>         <int>         <int>
#> 1 Neighbourhood Tra…          26       12          3             0             2
#> # ℹ 4 more variables: n_end_points <int>, n_paths <int>,
#> #   n_complete_paths <int>, n_screenout_paths <int>
```

Structural counts read straight off the survey definition: live
questions, blocks, branch points, block randomisers, Loop & Merge
blocks, and early-exit (`EndSurvey`) points. These describe the
programmed instrument, not any respondent. A high branch or early-exit
count means the survey routes people quite differently, so a single
burden figure would describe few of them.

## Paths

``` r

report$paths[, c("path_id", "status", "n_blocks",
                 "burden_floor", "burden_ceiling")]
#> # A tibble: 4 × 5
#>   path_id status     n_blocks burden_floor burden_ceiling
#>     <int> <fct>         <int>        <dbl>          <dbl>
#> 1       1 screen_out        2           12             12
#> 2       2 screen_out        3           14             14
#> 3       3 complete         12          103            145
#> 4       4 complete         11          103            139
```

Each **structural path** is one distinct block sequence a respondent
could take. `status` is `complete` (reaches a real submission) or
`screen_out` (hits an `EndSurvey` first). `burden_floor` and
`burden_ceiling` are the naive per-path bounds – only always-shown
questions, loops run once, versus every reachable question with loops at
their cap.

The printed “Display-logic combinations checked” line is the number of
feasible skip-logic states enumerated per complete path.

## Burden

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

- `points` is the GfS point total; `minutes` is `points` divided by the
  points-per-minute rate (default 12); `index` is `points / 1500`, a 0–1
  rescaling where 1.0 is the level Heimgartner and Axhausen’s sample
  found rare.
- `attr(, "basis")` is `"structural"` when the display-logic profile was
  enumerated (the default), `"naive"` when `profile = FALSE`, and
  `"none"` when no path completes. The naive band scores each optional
  question as independently hideable for the minimum and independently
  shown for the maximum; that is faster, but its minimum can fall below
  anything actually reachable and it reports no median. **Quote the
  structural basis.**
- The **benchmark** line is the published GfS reference point: a median
  of 399 points across the 79 scored survey waves in Heimgartner and
  Axhausen (2024). The verdict line’s ratio is the survey’s median over
  that 399.

The median here is the middle value across the feasible skip-logic
combinations, **not** the burden half of respondents exceed –
[`vignette("paths-and-display-logic")`](https://pmpk20.github.io/surveyBurden/articles/paths-and-display-logic.md)
returns to this.

Per-path structural figures are in `$paths`:

``` r

report$paths[, c("path_id", "status", "burden_min",
                 "burden_median", "burden_max")]
#> # A tibble: 4 × 5
#>   path_id status     burden_min burden_median burden_max
#>     <int> <fct>           <dbl>         <dbl>      <dbl>
#> 1       1 screen_out         12            12         12
#> 2       2 screen_out         14            14         14
#> 3       3 complete          106           124        143
#> 4       4 complete          106           122        139
```

These columns are `NA` when `profile = FALSE`.

## Burden by block

``` r

report$blocks[, c("block_name", "n_questions", "gfs_points", "share")]
#> # A tibble: 12 × 4
#>    block_name      n_questions gfs_points   share
#>    <chr>                 <int>      <dbl>   <dbl>
#>  1 Welcome                   1         11 0.0973 
#>  2 Consent                   1          1 0.00885
#>  3 Area check                1          2 0.0177 
#>  4 About you                 5         15 0.133  
#>  5 Household                 2          3 0.0265 
#>  6 Other adults              3          5 0.0442 
#>  7 Vehicles                  2         13 0.115  
#>  8 Vehicle details           3          6 0.0531 
#>  9 Travel                    2         26 0.230  
#> 10 Attitudes                 1         18 0.159  
#> 11 Commuting                 3          6 0.0531 
#> 12 Closing                   2          7 0.0619
```

Question burden totalled by block, in survey order, with each block’s
share of the all-questions-shown total. The printed bar chart is this
`share` column. Use it to see which modules drive the length.

## Highest-burden questions

The printed table lists the six questions with the largest single
`gfs_points`. The full per-question detail is `report$items`, including
the `score_basis` string that records the rule used for each:

``` r

head(report$items[order(-report$items$gfs_points),
                  c("question_id", "std_type", "gfs_points",
                    "score_flag", "score_basis")], 3)
#> # A tibble: 3 × 5
#>   question_id std_type     gfs_points score_flag score_basis                    
#>   <chr>       <chr>             <dbl> <chr>      <chr>                          
#> 1 QID21       matrix               18 auto       matrix, 6 rows x GfS rating >5…
#> 2 QID19       matrix               14 auto       matrix, 7 rows x GfS rating <=…
#> 3 QID14       multi_choice         12 auto       multi-select, 6 options -> GfS…
```

`score_flag` is `auto` (deterministic mapping), `inferred` (the mapping
needed a documented judgement), `manual` or `unknown`. See
[`vignette("gfs-scoring")`](https://pmpk20.github.io/surveyBurden/articles/gfs-scoring.md).

## Readability diagnostics

``` r

report$readability$stem_threshold
#> [1] 40
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

Three counts: question stems over `stem_threshold` words (default 40),
matrix row/option labels over `label_threshold` words (default 10), and
matrix questions with more than 6 rows. These are **reading-load
signals** reported separately – **none of them changes any GfS score**.
A long grid or a wordy stem is flagged so it is visible without being
silently priced into the burden total. Long grids in particular invite
satisficing (answering the same way down every row).

## Calculation certainty

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
report$certainty$display_logic[c("n_conditional", "n_exact", "n_approx")]
#> $n_conditional
#> [1] 6
#> 
#> $n_exact
#> [1] 6
#> 
#> $n_approx
#> [1] 0
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

For each survey this states which parts of the calculation are exact and
which rest on a documented approximation: how many paths resolve to a
single burden value, how many conditional questions were enumerated
exactly versus approximated, whether every loop has a known cap, and the
`auto` / `inferred` / `manual` / `unknown` split of the item scores. A
result can be fully reproducible without every underlying interpretation
being certain; this block makes the uncertain parts countable. Pass
`certainty = FALSE` to skip it.

## QC warnings

The printed report ends with plain-language flags: unscored question
types (the reported burden is then an under-count), long stems, long
labels, long grids, a high screen-out share, and a reminder that the
structural range is not a respondent probability. The full vector is
`report$warnings`.

``` r

report$warnings[1]
#> [1] "1 matrix/grid question has more than 6 rows. Long grids invite satisficing (respondents picking the same answer down the column instead of reading each row): QID19"
```

## References

- Heimgartner, D. and Axhausen, K. W. (2024). Predicting response rates
  once again. *Findings*.
  <https://findingspress.org/article/125481-predicting-response-rates-once-again>
