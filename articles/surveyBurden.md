# Get started with surveyBurden

`surveyBurden` estimates **ex-ante instrument burden**: the response
effort a programmed Qualtrics survey demands, worked out before fielding
from the instrument alone. It reads the survey, scores every question
with the published GfS / Axhausen point scheme, reconstructs the routes
the flow and display logic allow, and reports how burden varies across
those routes.

In the terms of Yan and Williams (2022) this is the *instrument* side of
respondent burden – length, difficulty, and the effort the design
requires. It is not the *perceived* burden a particular respondent
reports feeling, and it is not a completion-time predictor.

This article gets you to a first report. The others go deeper:

- [`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md)
  – what each part of the printed output means.
- [`vignette("gfs-scoring")`](https://pmpk20.github.io/surveyBurden/articles/gfs-scoring.md)
  – how a Qualtrics widget becomes points.
- [`vignette("paths-and-display-logic")`](https://pmpk20.github.io/surveyBurden/articles/paths-and-display-logic.md)
  – flow, skip logic, and the structural-versus-population-weighted
  distinction.
- [`vignette("calibration")`](https://pmpk20.github.io/surveyBurden/articles/calibration.md)
  – the `words_per_line` and points-per-minute assumptions, and the
  limitations.

## Install

``` r

# install.packages("pak")
pak::pak("pmpk20/surveyBurden")
```

## One call

``` r

library(surveyBurden)
demo <- system.file("extdata", "demo_travel_survey.qsf", package = "surveyBurden")
```

[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
runs the whole pipeline. Every code chunk in these articles runs against
the small fictional “Neighbourhood Travel Survey” that ships with the
package, so the numbers shown are the numbers the current package
produces. To use your own survey, replace `demo` with a path to a `.qsf`
file, a bare `SV_...` survey id, or a Qualtrics survey-builder URL (see
[`vignette("paths-and-display-logic")`](https://pmpk20.github.io/surveyBurden/articles/paths-and-display-logic.md)
for the API route).

``` r

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

The printout opens with a one-line **verdict**: the median
completing-path burden in points and minutes, its ratio to the 399-point
GfS benchmark, and the range across completing paths. Below it:

- **Instrument** – structural counts (questions, blocks, branch points,
  loop blocks, early exits).
- **Paths** – how many distinct routes the flow allows, and how many
  complete rather than screen out.
- **Burden** – the headline spread of path burden, in points, minutes
  and a 0–1 index, with the published benchmark underneath.
- **Burden by block**, **Highest-burden questions**, **Readability
  diagnostics**, **Calculation certainty**, **QC warnings**.

[`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md)
walks each of these in turn.

## Vocabulary

Five terms are used throughout, with fixed meanings:

| term | meaning |
|----|----|
| **question burden** | the GfS point score for one question, from its type and structure |
| **path burden** | the total question burden along one structural path through the survey flow |
| **structural burden profile** | the set of feasible burden values across a path’s display-logic sub-states, each counted once. Not a probability distribution. |
| **population-weighted respondent burden** | burden averaged over real respondent routes, where route frequencies stand in for the sub-state probabilities. Produced only when `routes` are supplied. |
| **calculation certainty** | the split, for a given survey, between parts of the calculation that are exact and parts that rest on documented approximations |
| **readability diagnostics** | counts of long question stems, long matrix labels, and long grids. Reading-load signals, reported separately, never folded into the GfS score. |

## The report object

`report` is a structured object, not printed text. Pull out each part:

``` r

report$burden      # min / p25 / median / p75 / max, in points, minutes and index
#> # A tibble: 5 × 4
#>   statistic points minutes  index
#>   <fct>      <dbl>   <dbl>  <dbl>
#> 1 min          106    8.83 0.0707
#> 2 p25          117    9.75 0.078 
#> 3 median       123   10.2  0.082 
#> 4 p75          129   10.8  0.086 
#> 5 max          143   11.9  0.0953
head(report$items[order(-report$items$gfs_points),
                  c("question_id", "std_type", "gfs_points", "score_flag")])
#> # A tibble: 6 × 4
#>   question_id std_type     gfs_points score_flag
#>   <chr>       <chr>             <dbl> <chr>     
#> 1 QID21       matrix               18 auto      
#> 2 QID19       matrix               14 auto      
#> 3 QID14       multi_choice         12 auto      
#> 4 QID20       matrix               12 auto      
#> 5 QID1        descriptive          11 inferred  
#> 6 QID7        matrix                8 auto
```

Other components: `report$instrument` (the structural counts),
`report$paths` (one row per structural path), `report$blocks` (burden by
block), `report$readability`, `report$certainty` and `report$warnings`.
Scalars such as the points-per-minute rate live on attributes:
`attr(report, "points_per_minute")`.

`summary(report)` prints just the headline:

``` r

summary(report)
#> 
#> ── Neighbourhood Travel Survey (demo) ──────────────────────────────────────────
#> 26 questions, 12 blocks, 4 structural paths (2 complete).
#> Median completing path: 123 GfS points, ~10 min - 0.3x the benchmark median of
#> 399. Path burden ranges 106-143 points (9-12 min) across 2 completing paths.
#> Benchmark: median 399 points across 79 GfS-scored waves.
```

## A short worked example

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

The two screen-out paths end early after the area check; the two
complete paths differ mainly in one branch-gated block. The spread from
minimum to maximum is the effect of the survey’s optional questions and
loop iterations, not measurement noise.

## References

- Heimgartner, D. and Axhausen, K. W. (2024). Predicting response rates
  once again. *Findings*.
  <https://findingspress.org/article/125481-predicting-response-rates-once-again>
- Yan, T. and Williams, D. (2022). Response burden: a review and
  conceptual framework. *Journal of Official Statistics*.
