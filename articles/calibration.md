# Calibration and limitations

This vignette covers two assumptions in the pipeline – words-to-lines
and points-to-minutes – and the limitations of the approach as a whole.
For the scoring rules see
[`vignette("gfs-scoring")`](https://pmpk20.github.io/surveyBurden/articles/gfs-scoring.md).

``` r

library(surveyBurden)
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
#> 4 p75          8.6 
#> 5 max          9.53
```

Alternatively, if you are calculating burden ex post then you can use
the completion-time data of your survey to calculate
[`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md)
and use the rate it returns:

``` r

w <- gfs_scheme()
w$points_per_minute <- validate_times(demo, "times.csv")$implied_points_per_minute
burden_report(demo, scheme = w)
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
- The structural profile is not a respondent distribution. Without route
  data, each complete path gets equal total weight and, within a path,
  each modelled display-logic state and loop count gets equal weight.
  “Median” means the median of that model-weighted distribution, not
  across respondents.
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

## References

- Heimgartner, D. and Axhausen, K. W. (2024). Predicting response rates
  once again. *Findings*.
  <https://findingspress.org/article/125481-predicting-response-rates-once-again>
- Yan, T. and Tourangeau, R. (2008). Fast times and easy questions: the
  effects of age, experience, and question complexity on web survey
  response times. *Applied Cognitive Psychology*.
