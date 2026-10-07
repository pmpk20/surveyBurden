# Get started with surveyBurden

`surveyBurden` estimates **survey burden**: the response effort a
programmed Qualtrics survey demands, worked out before fieldwork from
the survey alone. It reads the survey, scores every question with the
GfS+ point scheme (extending Heimgartner and Axhausen 2024),
reconstructs the paths the flow and display logic allow, and reports how
burden varies across those paths.

In the terms of Yan and Williams (2022) this is the *survey* side of
respondent burden – length, difficulty, and the effort the design
requires. It is not the *perceived* burden a particular respondent
reports feeling, and it is not a completion-time predictor.

This article gets you to a first report. Which function you need depends
on what you have:

| What you have | Start with | What you get | Guide |
|----|----|----|----|
| A Qualtrics survey (`.qsf` or API) | `burden_report(qsf)` | a model-based structural burden profile across the survey’s paths | [`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md) |
| A response export | `respondent_burden(qsf, responses)` | respondent burden: the GfS+ points displayed to each respondent | [`vignette("respondent-burden")`](https://pmpk20.github.io/surveyBurden/articles/respondent-burden.md) |
| A response export with completion times | `validate_times(qsf, observed)` | a check of respondent burden against observed time, and a survey-specific rate | [`vignette("calibration")`](https://pmpk20.github.io/surveyBurden/articles/calibration.md) |
| A draft you want to make lighter | [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md) before and after an edit | where the burden is, why, and how much a change removes | [`vignette("survey-revision")`](https://pmpk20.github.io/surveyBurden/articles/survey-revision.md) |
| A survey from another platform | `score_burden(validate_catalogue(catalogue))` | per-question scores and a total | [`vignette("extensions")`](https://pmpk20.github.io/surveyBurden/articles/extensions.md) |

The other articles go deeper:

- [`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md)
  – what each part of the printed output means.
- [`vignette("survey-revision")`](https://pmpk20.github.io/surveyBurden/articles/survey-revision.md)
  – finding the heaviest parts of a draft, changing them, and comparing
  before and after.
- [`vignette("gfs-scoring")`](https://pmpk20.github.io/surveyBurden/articles/gfs-scoring.md)
  – how a Qualtrics widget becomes points, and what the automatic scorer
  does and does not apply.
- [`vignette("paths-and-display-logic")`](https://pmpk20.github.io/surveyBurden/articles/paths-and-display-logic.md)
  – flow, skip logic, and the structural-versus-respondent distinction.
- [`vignette("calibration")`](https://pmpk20.github.io/surveyBurden/articles/calibration.md)
  – the `words_per_line` and points-per-minute assumptions, validating
  against completion times, and the limitations.
- [`vignette("respondent-burden")`](https://pmpk20.github.io/surveyBurden/articles/respondent-burden.md)
  – respondent burden from response data, and modelling break-off.
- [`vignette("extensions")`](https://pmpk20.github.io/surveyBurden/articles/extensions.md)
  – what works for surveys without a QSF, and what full support for
  another platform would take.

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
#>   survey -- Q1 --+               +-- Burden 0.2.0
#>                   '-- Q4 --------'
#> 
#> An R package for assessing the response-burden of web surveys
#> Docs: https://pmpk20.github.io/surveyBurden/
#> 
#> Please cite: King P (2026). surveyBurden: An R package for assessing
#> the response-burden of web surveys. R package version 0.2.0,
#> https://github.com/pmpk20/surveyBurden.
#> Use citation("surveyBurden") for BibTeX.
demo <- system.file("extdata", "demo_travel_survey.qsf", package = "surveyBurden")
```

[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
runs the whole pipeline. Every code chunk in these articles runs against
the small fictional “Neighbourhood Travel Survey” that ships with the
package, so the numbers shown are the numbers the current package
produces. To use your own survey, replace `demo` with a path to a `.qsf`
file, a bare `SV_...` survey id, or a Qualtrics survey-builder URL (see
[`?fetch_qsf`](https://pmpk20.github.io/surveyBurden/reference/fetch_qsf.md)
for fetching through the Qualtrics API).

``` r

report <- burden_report(demo, quiet = TRUE)
report
#> 
#> ── Survey Burden Report: Neighbourhood Travel Survey (demo) ────────────────────
#> Median burden: 123 GfS+ points (range 106-143 across 2 completing paths).
#> Expected minutes: ~10 (range 9-12).
#> Relative to benchmark: 0.3x the median of 399 points.
#> 
#> ── Survey ──
#> 
#> Questions (live)     26
#> Pages                12
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
#> Statistic        Points  Expected Minutes  Index
#> ------------------------------------------------
#> Minimum             106                 9   0.07
#> 25th percentile     117                10   0.08
#> Median              123                10   0.08
#> 75th percentile     130                11   0.09
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

The printout opens with a one-line **verdict**: the median
completing-path burden in points and minutes, its ratio to the 399-point
GfS benchmark, and the range across completing paths. Below it:

- **Survey** – structural counts (questions, blocks, branch points, loop
  blocks, early exits).
- **Paths** – how many distinct paths the flow allows, and how many
  complete rather than screen out.
- **Burden** – the headline spread of path burden, in points, minutes
  and an index (points / 1500, so 1 is a rare burden), with the
  published benchmark underneath.
- **Burden by block**, **Highest-burden questions**, **Readability
  diagnostics**, **Calculation certainty**, **QC warnings**.

[`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md)
walks each of these in turn.

## Vocabulary

These terms are used throughout, with fixed meanings. The key
distinction: a **path** is a possibility in the survey’s design; a
**respondent’s path** is the one a respondent actually took.

| term | meaning |
|----|----|
| **path** | one way through the survey that its flow allows: the blocks shown, given which branches are taken. Worked out from the survey design alone; no respondent is involved. |
| **question burden** | the GfS+ point score for one question, from its type and structure |
| **path burden** | the total question burden along one path. Display logic and loops can vary within a path, so a path has a spread of burdens rather than one number. |
| **structural burden profile** | the burden values a path’s modelled display-logic states produce, with model weights (equal per state; each path’s weights sum to 1). Not a respondent probability distribution. |
| **respondent burden** | the GfS+ points of every item displayed to one respondent, reconstructed from their responses: descriptive text and questions left blank included, each loop iteration counted ([`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)). |
| **calculation certainty** | counts, for a given survey, of the parts of the calculation that are enumerated in full within the model and the parts that rest on documented approximations. A modelling diagnostic, not a check against the live survey. |
| **readability diagnostics** | counts of long question stems, long matrix labels, and long grids. Reading-load signals, reported separately, never folded into the GfS+ score. |

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
#> 4 p75          130   10.8  0.0867
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

Other components: `report$survey` (the structural counts),
`report$paths` (one row per structural path), `report$blocks` (burden by
block), `report$readability`, `report$certainty` and `report$warnings`.
Scalars such as the points-per-minute rate live on attributes:
`attr(report, "points_per_minute")`.

`summary(report)` prints just the headline:

``` r

summary(report)
#> 
#> ── Neighbourhood Travel Survey (demo) ──────────────────────────────────────────
#> 26 questions, 12 pages, 12 blocks, 4 structural paths (2 complete).
#> Median burden: 123 GfS+ points (range 106-143 across 2 completing paths).
#> Expected minutes: ~10 (range 9-12).
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
