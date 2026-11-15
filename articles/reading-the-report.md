# Reading the burden report

**What this answers.** What each section of the printed
[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
output shows, and how to read it.

**What you need.** A report from
[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
on your survey’s `.qsf`.

**What to keep in mind.** The report describes the objective burden of
the survey’s design, the work its questions ask of respondents.
Completion time, break-off and data quality need response data, and the
report’s median describes the design, with every complete path weighted
equally.

This article walks through the printed
[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
output section by section. It covers what each section shows, how to
read it, and when it signals a problem. For how the underlying numbers
are produced see
[`vignette("gfs-scoring")`](https://pmpk20.github.io/surveyBurden/articles/gfs-scoring.md)
and
[`vignette("paths-and-display-logic")`](https://pmpk20.github.io/surveyBurden/articles/paths-and-display-logic.md).

``` r

library(surveyBurden)
#> 
#>                   .-- Q2 -- Q3 --.
#>   survey -- Q1 --+               +-- Burden 0.3.0
#>                   '-- Q4 --------'
#> 
#> An R package for assessing the response-burden of web surveys
#> Docs: https://pmpk20.github.io/surveyBurden/
#> 
#> Please cite: King P (2026). surveyBurden: An R package for assessing
#> the response-burden of web surveys. R package version 0.3.0,
#> https://github.com/pmpk20/surveyBurden.
#> Use citation("surveyBurden") for BibTeX.
demo <- system.file("extdata", "demo_travel_survey.qsf", package = "surveyBurden")
report <- burden_report(demo, quiet = TRUE)
report
#> 
#> ── Survey Burden Report: Neighbourhood Travel Survey (demo) ────────────────────
#> Median burden: 120 GfS+ points (range 103-143 across 2 completing paths).
#> Expected minutes: ~10 (range 9-12).
#> Relative to benchmark: 0.3x the median of 399 points.
#> 
#> ── Survey ──
#> 
#> Questions (live)        26
#> Pages                   12
#> Blocks                  12
#> Branch points            3
#> Randomisers              0
#> Loop & Merge blocks      2
#> End-of-survey elements   2
#> 
#> ── Paths ──
#> 
#> Structural paths: 4 (2 complete, 2 screen-out)
#> Display-logic trigger questions: 3-4 per complete path
#> 
#> ── Burden (12 GfS+ points ~ 1 minute; index = points / 1500) ──
#> 
#> Statistic        Points  Expected Minutes  Index
#> ------------------------------------------------
#> Minimum             103                 9   0.07
#> 25th percentile     114                10   0.08
#> Median              120                10   0.08
#> 75th percentile     126                10   0.08
#> Maximum             143                12   0.10
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
#> Joint enumeration limit: 10000 condition states per component.
#> Loops: 2 with a known cap, 0 unknown.  Item scores: 19 auto / 7 inferred / 0
#> manual.
#> 
#> ── QC warnings (3) ──
#> 
#> ! 1 matrix/grid question has more than 6 rows. Long grids invite satisficing (respondents picking the same answer down the column instead of reading each row): QID19
#> ! 2 of 4 structural paths are screen-outs (the survey ends early there) rather than complete responses.
#> ! The point range above comes from the combinations of optional questions the package can model for this survey's flow and skip logic. Each complete path carries equal weight, and so does each modelled combination within a path; these are model weights, not how often respondents see each one, so this is a structural range, not a probability -- it does NOT mean "there's a 50% chance a respondent sees the median burden".
```

## The headline

The first line under the title summarises the survey in plain language.
It gives the median burden of the complete paths in GfS+ points and in
minutes, its ratio to the 399-point GfS benchmark, and the point range
across the complete paths. When you supply `responses`, it also reports
the median respondent burden over complete responses (see
[`vignette("respondent-burden")`](https://pmpk20.github.io/surveyBurden/articles/respondent-burden.md)).

`summary(report)` prints the same headline with the structural counts
alone.

## Survey

``` r

report$survey
#> # A tibble: 1 × 11
#>   survey_name              n_questions n_pages n_blocks n_branches n_randomisers
#>   <chr>                          <int>   <int>    <int>      <int>         <int>
#> 1 Neighbourhood Travel Su…          26      12       12          3             0
#> # ℹ 5 more variables: n_loop_blocks <int>, n_end_points <int>, n_paths <int>,
#> #   n_complete_paths <int>, n_screenout_paths <int>
```

These structural counts come straight from the survey (editing URL or
QSF). They are live questions, blocks, branch points, block randomisers,
Loop & Merge blocks and early-exit (`EndSurvey`) points, and they
describe the programmed survey. A high branch or early-exit count means
the survey routes people quite differently, so a single burden figure
would describe few of them.

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

Each **path** is one distinct block sequence a respondent could take.
`status` is `complete` (the path reaches a real submission) or
`screen_out` (it hits an `EndSurvey` first). `burden_floor` and
`burden_ceiling` are simple bounds for each path. The floor counts only
the questions always shown, with loops run once. The ceiling counts
every reachable question, with loops at their cap.

The printed “Display-logic trigger questions” line gives the range of
`n_gates` across complete paths. `n_gates` counts the distinct questions
on a path whose answers decide whether some other question is shown. It
counts trigger questions, and one trigger question with five answer
options can produce several display-logic combinations.

## Burden

``` r

report$burden
#> # A tibble: 5 × 4
#>   statistic points minutes  index
#>   <fct>      <dbl>   <dbl>  <dbl>
#> 1 min          103    8.58 0.0687
#> 2 p25          114    9.5  0.076 
#> 3 median       120   10    0.08  
#> 4 p75          126   10.5  0.084 
#> 5 max          143   11.9  0.0953
attr(report$burden, "basis")
#> [1] "structural"
```

- `points` is the GfS+ point total. `minutes` is `points` divided by the
  points-per-minute rate (default 12). `index` is `points / 1500`, where
  1.0 is the level above which Heimgartner and Axhausen (2024) found
  surveys to be rare. A survey can exceed 1.
- `attr(, "basis")` is `"structural"` when the display-logic profile was
  enumerated (the default), `"naive"` when `profile = FALSE`, and
  `"none"` when no path completes. The naive band treats each optional
  question as hidden for the minimum and shown for the maximum,
  independently of the others. It runs faster, but its minimum can fall
  below any reachable combination and it reports no median. **Quote the
  structural basis.**
- The **benchmark** line is the published GfS reference point, a median
  of 399 points across the 79 scored survey waves in Heimgartner and
  Axhausen (2024). The headline’s ratio is the survey’s median divided
  by 399.

The median here is the middle value of the modelled display-logic
combinations, with each complete path given equal total weight. It
describes the design. The burden that half of respondents exceeded comes
from response data
([`vignette("respondent-burden")`](https://pmpk20.github.io/surveyBurden/articles/respondent-burden.md)).
[`vignette("paths-and-display-logic")`](https://pmpk20.github.io/surveyBurden/articles/paths-and-display-logic.md)
explains the weighting.

`$paths` holds the structural figures for each path.

``` r

report$paths[, c("path_id", "status", "burden_min",
                 "burden_median", "burden_max")]
#> # A tibble: 4 × 5
#>   path_id status     burden_min burden_median burden_max
#>     <int> <fct>           <dbl>         <dbl>      <dbl>
#> 1       1 screen_out         12            12         12
#> 2       2 screen_out         14            14         14
#> 3       3 complete          103           121        143
#> 4       4 complete          103           119        139
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

This table totals question burden by block, in survey order, with each
block’s share of the total when every question is shown. The printed bar
chart is the `share` column. Use it to see which blocks make the survey
long.

## Highest-burden questions

The printed table lists the six questions with the largest single
`gfs_points`. `report$items` holds the full detail for every question,
including the `score_basis` string that records the rule used.

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

`score_flag` is `auto` (the structure fixes the mapping), `inferred`
(the mapping needed a documented judgement), `manual` or `unknown`. See
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

This section gives three counts. They are question stems over
`stem_threshold` words (default 40), matrix row or option labels over
`label_threshold` words (default 10), and matrix questions with more
than 6 rows. These are **reading-load signals**, reported alongside the
GfS+ score and kept out of it, so a long grid or a wordy stem is visible
on its own. Long grids invite satisficing (answering the same way down
every row).

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

For each survey, this section counts which parts of the calculation rest
on a documented approximation. It reports

- how many complete paths have every display-logic question resolved,
- how many conditional questions were enumerated in full (every state
  the model represents) and how many were approximated,
- whether every loop has a known cap, and
- how the item scores split between `auto`, `inferred`, `manual` and
  `unknown`.

These counts diagnose the model. Branch conditions, embedded-data
conditions and unusual Qualtrics constructs fall outside what they
check, so a full count certifies the model and leaves the live survey to
you. A result can be fully reproducible while some interpretations stay
uncertain, and this section makes the uncertain parts countable. Pass
`certainty = FALSE` to skip it.

## QC warnings

The printed report ends with plain-language flags. They cover unscored
question types (which make the reported burden an under-count), long
stems, long labels, long grids, a high screen-out share, and a reminder
that the structural range uses model weights. `report$warnings` holds
the full list.

``` r

report$warnings[1]
#> [1] "1 matrix/grid question has more than 6 rows. Long grids invite satisficing (respondents picking the same answer down the column instead of reading each row): QID19"
```

## Next

- [`vignette("survey-revision")`](https://pmpk20.github.io/surveyBurden/articles/survey-revision.md)
  acts on the heaviest blocks and questions.
- [`vignette("paths-and-display-logic")`](https://pmpk20.github.io/surveyBurden/articles/paths-and-display-logic.md)
  shows how the paths and the burden spread are built.
- [`vignette("calibration")`](https://pmpk20.github.io/surveyBurden/articles/calibration.md)
  covers the points-to-minutes assumption and the limitations.

## References

- Heimgartner, D. and Axhausen, K. W. (2024). Predicting response rates
  once again. *Findings*. <https://doi.org/10.32866/001c.125481>
