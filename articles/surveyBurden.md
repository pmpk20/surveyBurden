# Get started with surveyBurden

surveyBurden measures how much work a survey asks of the people who
answer it. It reads a programmed Qualtrics survey, scores every question
in GfS+ points, follows the survey’s flow and display logic to find the
paths through it, and reports how burden varies across those paths. All
of this works from the survey alone, before fieldwork.

The survey literature calls this objective burden. It is the work a
survey asks of respondents, measured from the questions themselves (how
many there are and how much effort each takes to answer). Perceived
burden, how burdensome respondents feel the survey to be, is measured
separately, for example by asking respondents directly (Yan and Williams
2022).

GfS stands for Gesellschaft für Sozialforschung (Society for Social
Research), the Zürich organisation whose point system for budgeting
face-to-face interviews Axhausen and colleagues adapted to
self-administered surveys (Schmid and Axhausen 2019). surveyBurden uses
the current version of their table (Heimgartner and Axhausen 2024) and
adds documented rules for further question types, hence the “+”.

This article gets you to a first report. The function you need depends
on what you have.

| What you have | Start with | What you get | Guide |
|----|----|----|----|
| A Qualtrics survey (`.qsf` or API) | `burden_report(qsf)` | the full report, with burden across the survey’s paths | [`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md) |
| A response export | `respondent_burden(qsf, responses)` | the burden each respondent was shown | [`vignette("respondent-burden")`](https://pmpk20.github.io/surveyBurden/articles/respondent-burden.md) |
| A response export with completion times | `validate_times(qsf, observed)` | a check of respondent burden against time taken, and a points-per-minute rate for your survey | [`vignette("calibration")`](https://pmpk20.github.io/surveyBurden/articles/calibration.md) |
| A draft you want to shorten | [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md) before and after an edit | where the burden is, why, and how much an edit removes | [`vignette("survey-revision")`](https://pmpk20.github.io/surveyBurden/articles/survey-revision.md) |
| A survey from another platform | `score_burden(validate_catalogue(catalogue))` | a score for each question and a survey total | [`vignette("extensions")`](https://pmpk20.github.io/surveyBurden/articles/extensions.md) |

The other articles go deeper.

- [`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md)
  explains each part of the printed report.
- [`vignette("survey-revision")`](https://pmpk20.github.io/surveyBurden/articles/survey-revision.md)
  finds the heaviest parts of a draft and compares burden before and
  after an edit.
- [`vignette("gfs-scoring")`](https://pmpk20.github.io/surveyBurden/articles/gfs-scoring.md)
  shows how a Qualtrics question becomes points, and which rules the
  automatic scorer applies.
- [`vignette("paths-and-display-logic")`](https://pmpk20.github.io/surveyBurden/articles/paths-and-display-logic.md)
  covers flow, skip logic and the difference between a path and a
  respondent’s path.
- [`vignette("calibration")`](https://pmpk20.github.io/surveyBurden/articles/calibration.md)
  covers the `words_per_line` and points-per-minute assumptions,
  checking scores against completion times, and the limitations.
- [`vignette("respondent-burden")`](https://pmpk20.github.io/surveyBurden/articles/respondent-burden.md)
  measures respondent burden from response data and prepares data for
  modelling break-off.
- [`vignette("extensions")`](https://pmpk20.github.io/surveyBurden/articles/extensions.md)
  shows what works for surveys from other platforms, and what full
  support for another platform would take.

## Install

``` r

# install.packages("pak")
pak::pak("pmpk20/surveyBurden")
```

## One call

``` r

library(surveyBurden)
#> 
#>                   .-- Q2 -- Q3 --.
#>   survey -- Q1 --+               +-- Burden 0.3.1
#>                   '-- Q4 --------'
#> 
#> Measuring the Response Burden of Web Surveys
#> Docs: https://pmpk20.github.io/surveyBurden/
#> 
#> Please cite: King P (2026). surveyBurden: Measuring the Response Burden
#> of Web Surveys. R package version 0.3.1,
#> https://github.com/pmpk20/surveyBurden.
#> Use citation("surveyBurden") for BibTeX.
demo <- system.file("extdata", "demo_travel_survey.qsf", package = "surveyBurden")
```

[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
runs the whole pipeline. Every code chunk in these articles runs against
the small fictional “Neighbourhood Travel Survey” that ships with the
package, so the numbers shown are the numbers the current package
produces. To use your own survey, replace `demo` with a path to a `.qsf`
file, a bare `SV_...` survey ID, or a Qualtrics survey-builder URL.
[`?fetch_qsf`](https://pmpk20.github.io/surveyBurden/reference/fetch_qsf.md)
explains fetching through the Qualtrics API.

``` r

report <- burden_report(demo, quiet = TRUE)
report
#> 
#> ── Survey Burden Report: Neighbourhood Travel Survey (demo) ────────────────────
#> Median burden: 120 GfS+ points (range 103-143 across 2 complete routes).
#> Expected duration in minutes: ~10 (range 9-12).
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
#> ── Routes ──
#> 
#> Routes: 4 (2 complete, 2 end early)
#> Questions that control display logic: 3-4 per complete route
#> 
#> ── Burden (12 GfS+ points ~ 1 minute; index = points / 1500) ──
#> 
#> Statistic        Points  Expected Duration (min)  Index
#> -------------------------------------------------------
#> Minimum             103                        9   0.07
#> 25th percentile     114                       10   0.08
#> Median              120                       10   0.08
#> 75th percentile     126                       10   0.08
#> Maximum             143                       12   0.10
#> Benchmark: median 399 points across 79 survey waves (Heimgartner & Axhausen
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
#> 2 complete routes. On both, some items are shown only if earlier answers meet a
#> display condition.
#> 3 branches depend on answers to questions in the survey (QID2, QID3, QID6).
#> Every possible outcome of each branch is included.
#> 6 items have display logic.
#> All 6 were evaluated for every combination of answers (limit 10,000
#> combinations per linked set).
#> None was approximated.
#> The 4 unlinked sets of display conditions are combined as if independent.
#> 2 Loop & Merge blocks have a fixed maximum. Other adults: 0 to 5 repetitions.
#> Vehicle details: 0 to 3 repetitions.
#> 19 items scored automatically, 7 by inference, 0 from user input, 0 unscored.
#> 
#> ── QC warnings (3) ──
#> 
#> ! 1 matrix or grid question has more than 6 rows. Long grids invite satisficing. That is when respondents pick the same answer down the column instead of reading each row: QID19
#> ! 2 of 4 routes end the survey early instead of reaching the end.
#> ! The range above covers every combination of answers the package can model, with each route and each combination weighted equally. It does not show how many respondents will see each burden value.
```

The printout opens with a headline. It gives the median burden of the
complete paths in points and minutes, its ratio to the 399-point median
of the GfS benchmark, and the range across complete paths. The sections
below it are these.

- **Survey** counts the questions, blocks, branch points, loop blocks
  and early exits.
- **Paths** counts the distinct paths the flow allows, and how many run
  to the end of the survey or end early at a screen-out.
- **Burden** gives the spread of path burden in points, minutes and an
  index. The index divides points by 1,500, the level above which
  Heimgartner and Axhausen (2024) found surveys to be rare, so an index
  of 1 marks a rare burden. The published benchmark is printed
  underneath.
- **Burden by block**, **Highest-burden questions**, **Readability
  diagnostics**, **Calculation certainty** and **QC warnings** follow.

[`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md)
walks through each section.

## Terms used in these articles

Each term below has one fixed meaning across the package and its guides.
The most important distinction is between a **path**, which is a
possibility in the survey’s design, and a respondent’s path, which is
the route one person actually took.

| term | meaning |
|----|----|
| **path** | one route through the survey that its flow allows. A path is the sequence of blocks shown, given which branches are taken. It is worked out from the survey design alone. |
| **question burden** | the GfS+ points for one question, from its type and structure |
| **path burden** | the total question burden along one path. Display logic and loops can vary within a path, so a path has a range of burdens. |
| **structural burden profile** | the burden values a path’s modelled display-logic combinations produce, each with an equal model weight (each path’s weights sum to 1). The weights describe the design. Shares of respondents come from respondent burden after fieldwork. |
| **respondent burden** | the GfS+ points of every item shown to one respondent, reconstructed from their responses. It includes descriptive text and questions left blank, and counts each loop iteration ([`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)). |
| **calculation certainty** | for a given survey, how many parts of the calculation the model enumerates in full and how many rest on documented approximations. It diagnoses the model of the survey. |
| **readability diagnostics** | counts of long question stems, long matrix labels and long grids. They signal reading load and are reported separately from the GfS+ score. |

## The report object

`report` is a structured R object, so you can pull out each part.

``` r

report$burden      # min / p25 / median / p75 / max, in points, minutes and index
#> # A tibble: 5 × 4
#>   statistic points minutes  index
#>   <fct>      <dbl>   <dbl>  <dbl>
#> 1 min          103    8.58 0.0687
#> 2 p25          114    9.5  0.076 
#> 3 median       120   10    0.08  
#> 4 p75          126   10.5  0.084 
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

The other components are `report$survey` (the structural counts),
`report$paths` (one row per path), `report$blocks` (burden by block),
`report$readability`, `report$certainty` and `report$warnings`. Single
settings such as the points-per-minute rate are stored as attributes,
for example `attr(report, "points_per_minute")`.

`summary(report)` prints the headline alone.

``` r

summary(report)
#> 
#> ── Neighbourhood Travel Survey (demo) ──────────────────────────────────────────
#> 26 questions, 12 pages, 12 blocks, 4 routes (2 complete).
#> Median burden: 120 GfS+ points (range 103-143 across 2 complete routes).
#> Expected duration in minutes: ~10 (range 9-12).
#> Relative to benchmark: 0.3x the median of 399 points.
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
#> 3       3 complete                  20                  26        103        143
#> 4       4 complete                  20                  23        103        139
```

The two screen-out paths end early after the area check. The two
complete paths differ mainly in one block that a branch shows to some
respondents. Within each path, the spread from minimum to maximum comes
from the survey’s optional questions and loop iterations.

## References

- Heimgartner, D. and Axhausen, K. W. (2024). Predicting response rates
  once again. *Findings*. <https://doi.org/10.32866/001c.125481>
- Schmid, B. and Axhausen, K. W. (2019). Predicting response rates of
  all and recruited respondents: a first attempt. *Findings*.
  <https://doi.org/10.32866/7827>
- Yan, T. and Williams, D. (2022). Response burden: review and
  conceptual framework. *Journal of Official Statistics* 38(4), 939–961.
  <https://doi.org/10.2478/jos-2022-0041>
