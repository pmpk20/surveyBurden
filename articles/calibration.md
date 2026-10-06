# Calibration and limitations

**What this answers.** How the two conversion assumptions (words per
line, points per minute) work, how to check predictions against observed
completion times, and the limitations of the approach.

**What you need.** A `.qsf`; for validation, the response export, with
completion times.

**What it cannot establish.** An implied points-per-minute rate is
rough, trim-sensitive and specific to one survey. Burden scores do not
predict dropout, satisficing or data quality.

This vignette covers two assumptions in the pipeline – words-to-lines
and points-to-minutes – and the limitations of the approach as a whole.
For the scoring rules see
[`vignette("gfs-scoring")`](https://pmpk20.github.io/surveyBurden/articles/gfs-scoring.md).

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

## words_per_line

In the original GfS scheme, a score is provided for each additional line
of text in the survey. However, a `.qsf` does not provide the number of
additional lines of text, as this may vary with the survey mode.
Instead, it returns the words per question. The package, therefore,
assumes that the number of words that make an additional line
(`words_per_line` = default 12). This is a practical proxy, that you can
set if you wish, and means that assigned GfS+ points per
descriptive-text in your survey should be read as approximate. This
assumption only affects descriptive / instruction-text scores and every
other question type is unaffected.

You can set the words per line in your survey with:

``` r

burden_report(demo, words_per_line = 8, quiet = TRUE)$burden$points[1:2]
#> [1] 112 123
```

## points_per_minute

To convert GfS+ points to minutes of survey time, the GfS rule of thumb
is 12 points per minute. As a rule of thumb, do not assume that it
predicts the completion time, or applies to online surveys. You can
either override it by setting `points_per_minute` on a weights object:

``` r

w <- gfs_scheme()
w$points_per_minute <- 15
burden_report(demo, scheme = w, quiet = TRUE)$burden[, c("statistic", "minutes")]
#> # A tibble: 5 × 2
#>   statistic minutes
#>   <fct>       <dbl>
#> 1 min          7.07
#> 2 p25          7.8 
#> 3 median       8.2 
#> 4 p75          8.67
#> 5 max          9.53
```

Alternatively, if you are calculating burden after fieldwork then you
can use the completion-time data of your survey to calculate
[`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md)
and use the rate it returns.

### Validating against completion times

[`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md)
takes each respondent’s burden from
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
and compares it with their completion time. It needs the response export
itself, so that each respondent’s path can be reconstructed. Prepare the
data first:

1.  **Keep completed responses.** With a `Finished` column, only
    finishers are kept (`finished_only = TRUE`); without one, filter
    yourself, since `trim` filters on duration alone.
2.  **Provide a duration column.** Qualtrics’ own
    `Duration (in seconds)` is read directly (also as
    [`read.csv()`](https://rdrr.io/r/utils/read.table.html) renames it),
    as are `completion_seconds` and `completion_mins`; the first found
    wins. The two header rows of a raw CSV export are removed
    automatically when recognisable.
3.  **Choose the trim.** The default keeps 3 to 180 minutes, to drop
    speeders and people who left the survey open. Report how many rows
    it removed (`n` against your row count); the implied rate is
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
#>        0.92        0.03        9.41
```

Reading the output:

- `ratio` is the predicted median over the observed median, in minutes.
- `cor` is the correlation of respondent burden with observed minutes.
  Completion times vary for many reasons besides survey content, so
  expect it to be small on real data.
- `implied_points_per_minute` is `60 / b`, where `b` is the slope, in
  seconds per point, of a through-origin fit of observed seconds on
  predicted points. It is a rough, trim-sensitive rate for this survey,
  not a calibrated constant.

To use that rate:

``` r

w <- gfs_scheme()
w$points_per_minute <- vt$implied_points_per_minute
burden_report(demo, scheme = w, quiet = TRUE)$burden[, c("statistic", "minutes")]
#> # A tibble: 5 × 2
#>   statistic minutes
#>   <fct>       <dbl>
#> 1 min          11.3
#> 2 p25          12.4
#> 3 median       13.1
#> 4 p75          13.8
#> 5 max          15.2
```

## Limitations

- The Qualtrics-to-GfS+ mapping is sometimes inferential. Where a
  question type has no exact match in Table 1, the package applies a
  documented rule and flags the question `inferred`.
- The original GfS scheme predates modern web survey interfaces. It was
  calibrated on earlier survey practice.
- Rendered text length cannot be recovered from a `.qsf`. The file
  stores words, not an on-screen line count; `words_per_line` is a
  configurable proxy for that missing count, not a measured constant.
- Display-logic reconstruction depends on what the `.qsf` encodes. Logic
  controlled outside Qualtrics, or unusual constructs, may need manual
  interpretation.
- The structural profile is not a respondent distribution. Without
  response data, each complete path gets equal total weight and, within
  a path, each modelled display-logic state and loop count gets equal
  weight. “Median” means the median of that model-weighted distribution,
  not across respondents.
- Structural paths are the block sequences the flow allows. Branch
  conditions are not evaluated or checked against each other, so the
  minimum or maximum may not be reachable by a real respondent.
- Loop & Merge can make the path space large. The package unrolls to the
  explicit cap and treats the iteration count as uniform.
- The points-to-minutes conversion is the original GfS rule of thumb,
  roughly 12 points per minute.
- Burden scores are not predictions of completion time, dropout, or
  satisficing. Those are empirical questions about respondent behaviour,
  outside the scope of this package.

## Next

- [`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md)
  – reading the full report.
- [`vignette("respondent-burden")`](https://pmpk20.github.io/surveyBurden/articles/respondent-burden.md)
  – respondent burden after fielding.

## References

- Heimgartner, D. and Axhausen, K. W. (2024). Predicting response rates
  once again. *Findings*.
  <https://findingspress.org/article/125481-predicting-response-rates-once-again>
- Yan, T. and Tourangeau, R. (2008). Fast times and easy questions: the
  effects of age, experience, and question complexity on web survey
  response times. *Applied Cognitive Psychology*.
