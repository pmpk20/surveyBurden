# Calibration and limitations

**What this answers.** How the two conversion assumptions (words per
line, points per minute) work, how to check predictions against observed
completion times, and the limitations of the approach.

**What you need.** A `.qsf`, and for validation, the response export
with completion times.

**What to keep in mind.** An implied points-per-minute rate is rough and
specific to one survey. Burden scores measure objective burden, and
links to break-off, satisficing or data quality need their own analysis.

This article covers two assumptions in the pipeline, words-to-lines and
points-to-minutes, and the limitations of the approach as a whole. For
the scoring rules see
[`vignette("gfs-scoring")`](https://pmpk20.github.io/surveyBurden/articles/gfs-scoring.md).

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
```

## words_per_line

The GfS scheme scores each additional line of descriptive text. A `.qsf`
stores the words of each question, and the number of lines they fill
varies with the screen. The package therefore assumes a number of words
per line (`words_per_line`, default 12). This is a practical
approximation that you can change, so read the GfS+ points for
descriptive text as approximate. The assumption affects descriptive and
instruction text only, and every other question type keeps the same
score.

Set the words per line for your survey like this.

``` r

burden_report(demo, words_per_line = 8, quiet = TRUE)$burden$points[1:2]
#> [1] 109 120
```

## points_per_minute

The GfS rule of thumb converts points to minutes at 12 points per
minute. Treat it as a rough guide to completion time, especially for
online surveys. You can override it by setting `points_per_minute` on a
weights object.

``` r

w <- gfs_scheme()
w$points_per_minute <- 15
burden_report(demo, scheme = w, quiet = TRUE)$burden[, c("statistic", "minutes")]
#> # A tibble: 5 × 2
#>   statistic minutes
#>   <fct>       <dbl>
#> 1 min          6.87
#> 2 p25          7.6 
#> 3 median       8   
#> 4 p75          8.4 
#> 5 max          9.53
```

After fieldwork, you can instead estimate a rate from your survey’s
completion times with
[`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md)
and use the rate it returns.

### Validating against completion times

[`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md)
takes each respondent’s burden from
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
and compares it with their completion time. It needs the response export
itself, so that each respondent’s path can be reconstructed. Prepare the
data first.

1.  **Keep completed responses.** With a `Finished` column, only
    finishers are kept (`finished_only = TRUE`). Without one, filter the
    data yourself, because `trim` filters on duration alone.
2.  **Provide a duration column.** The package reads Qualtrics’ own
    `Duration (in seconds)` directly (also under the name
    [`read.csv()`](https://rdrr.io/r/utils/read.table.html) gives it),
    as well as `completion_seconds` and `completion_mins`, and uses the
    first it finds. It removes the two header rows of a raw CSV export
    automatically when it recognises them.
3.  **Choose the trim.** The default keeps 3 to 180 minutes, to drop
    speeders and people who left the survey open. Report how many rows
    it removed (`n` against your row count), because the implied rate is
    sensitive to it.

A simulated example:

``` r

set.seed(2)
n <- 120
export <- data.frame(
  ResponseId = paste0("R_", seq_len(n)),
  Finished   = rbinom(n, 1, 0.9),                    # 1 = completed
  `Duration (in seconds)` = round(rlnorm(n, log(600), 0.5)),
  check.names = FALSE
)
# answers: each respondent answers a different number of the core questions
cat_ <- parse_qsf(read_qsf(demo))
core <- cat_$question_id[!cat_$in_loop]
k <- sample(5:length(core), n, TRUE)
for (j in seq_along(core)) export[[core[j]]] <- ifelse(j <= k, "1", NA)

vt <- validate_times(demo, export, trim = c(3, 180))
c(rows = nrow(export), finished = sum(export$Finished), kept_after_trim = vt$n)
#>            rows        finished kept_after_trim 
#>             120             107             107
round(c(ratio = vt$ratio, cor = vt$cor,
        implied_ppm = vt$implied_points_per_minute), 2)
#>       ratio         cor implied_ppm 
#>        0.92        0.03       11.10
```

How to read the output:

- `ratio` is the predicted median over the observed median, in minutes.
- `cor` is the correlation of respondent burden with observed minutes.
  Completion times vary for many reasons besides survey content, so
  expect it to be small on real data.
- `implied_points_per_minute` is the median respondent burden divided by
  the median observed time, over the respondents kept. Medians stop a
  few respondents who left the survey open from dominating it. It is a
  rough rate for this survey.
- `ols_points_per_minute` is the older estimate, `60 / b` from a
  through-origin fit of observed seconds on predicted points. Long
  completion times dominate it, so use it as a comparison only.

To use the implied rate:

``` r

w <- gfs_scheme()
w$points_per_minute <- vt$implied_points_per_minute
burden_report(demo, scheme = w, quiet = TRUE)$burden[, c("statistic", "minutes")]
#> # A tibble: 5 × 2
#>   statistic minutes
#>   <fct>       <dbl>
#> 1 min          9.28
#> 2 p25         10.3 
#> 3 median      10.8 
#> 4 p75         11.4 
#> 5 max         12.9
```

## Limitations

- Some question types lack an exact match in Table 1. For these the
  package applies a documented rule and flags the question `inferred`.
- The original GfS scheme predates modern web survey interfaces and was
  calibrated on earlier survey practice.
- A `.qsf` stores words, and the on-screen line count depends on the
  display. `words_per_line` is a configurable approximation for that
  count.
- Display-logic reconstruction depends on what the `.qsf` encodes. Logic
  controlled outside Qualtrics, and unusual constructs, may need
  checking by hand.
- The structural profile weights the design. Without response data, each
  complete path gets equal total weight, and within a path each modelled
  display-logic state and loop count gets equal weight. “Median” means
  the median of that model-weighted distribution. Medians across
  respondents come from response data.
- Structural paths are the block sequences the flow allows. Most branch
  conditions are kept both ways and treated independently, so the
  minimum or maximum may come from a route whose conditions contradict
  each other.
- Loop & Merge can make the path space large. The package unrolls loops
  to the explicit cap and treats the iteration count as uniform.
- The points-to-minutes conversion is the original GfS rule of thumb,
  roughly 12 points per minute.
- Burden scores measure objective burden. Completion time, break-off and
  satisficing are respondent behaviours that need response data to
  study.
  [`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md)
  and
  [`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
  provide the inputs.

## Next

- [`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md)
  explains the full report.
- [`vignette("respondent-burden")`](https://pmpk20.github.io/surveyBurden/articles/respondent-burden.md)
  covers respondent burden after fieldwork.

## References

- Heimgartner, D. and Axhausen, K. W. (2024). Predicting response rates
  once again. *Findings*. <https://doi.org/10.32866/001c.125481>
- Yan, T. and Tourangeau, R. (2008). Fast times and easy questions: the
  effects of age, experience, and question complexity on web survey
  response times. *Applied Cognitive Psychology* 22(1), 51–68.
  <https://doi.org/10.1002/acp.1331>
