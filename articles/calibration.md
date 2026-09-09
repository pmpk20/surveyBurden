# Calibration and limitations

This article covers the two conversion assumptions in the pipeline –
words-to-lines and points-to-minutes – and the limitations of the
approach as a whole. For the scoring rules see
[`vignette("gfs-scoring")`](https://pmpk20.github.io/surveyBurden/articles/gfs-scoring.md).

``` r

library(surveyBurden)
demo <- system.file("extdata", "demo_travel_survey.qsf", package = "surveyBurden")
```

## words_per_line

GfS Table 1 scores instruction text in rendered lines. A `.qsf` stores
words, not the width the respondent’s browser will render them at. The
package approximates lines as words divided by `words_per_line` (default
12). It is a practical proxy, not a calibration, and it is the reason
the descriptive-text score for a long instruction block should be read
as approximate.

Override it per report if your survey theme has a known typical line
length:

``` r

burden_report(demo, words_per_line = 8, quiet = TRUE)$burden$points[1:2]
#> [1] 112 123
```

Only descriptive / instruction-text scores depend on it; every other
question type is unaffected.

## points_per_minute

The GfS framework uses roughly 12 points per minute as a rule of thumb,
from the original framework. It is a rough scale, **not** a web-specific
calibration and **not** a prediction of completion time. Override it by
setting `points_per_minute` on a weights object:

``` r

w <- gfs_weights()
w$points_per_minute <- 15
burden_report(demo, weights = w, quiet = TRUE)$burden[, c("statistic", "minutes")]
#> # A tibble: 5 × 2
#>   statistic minutes
#>   <fct>       <dbl>
#> 1 min          7.07
#> 2 p25          7.8 
#> 3 median       8.2 
#> 4 p75          8.6 
#> 5 max          9.53
```

For a figure specific to your survey, fit one to your own
completion-time data with
[`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md)
and use the rate it returns. This needs a completion-time file the
package does not ship, so it is not run here:

``` r

w <- gfs_weights()
w$points_per_minute <- validate_times(demo, "times.csv")$implied_points_per_minute
burden_report(demo, weights = w)
```

## Limitations

- The Qualtrics-to-GfS mapping is sometimes inferential. Where a widget
  has no exact match in Table 1, the package applies a documented rule
  and flags the question `inferred`.
- The GfS scheme predates modern web survey interfaces. It was
  calibrated on earlier survey practice.
- Rendered text length cannot be recovered from a `.qsf`. The file
  stores words, not an on-screen line count; `words_per_line` is a
  configurable proxy for that missing count, not a measured constant.
- Display-logic reconstruction depends on what the `.qsf` encodes. Logic
  controlled outside Qualtrics, or unusual constructs, may need manual
  interpretation.
- Structural enumeration gives no respondent probabilities. Without
  route data every feasible combination is counted once, and “median”
  means the median across combinations, not across respondents.
- Loop & Merge can make the path space large. The package unrolls to the
  explicit cap and treats the iteration count as uniform.
- The points-to-minutes conversion is the published GfS rule of thumb,
  roughly 12 points per minute. It is a scale, not a completion-time
  prediction.
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
