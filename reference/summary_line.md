# One-sentence summary of a burden object

One-sentence summary of a burden object

## Usage

``` r
summary_line(x, ...)
```

## Arguments

- x:

  A
  [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  object.

- ...:

  Unused.

## Value

A single character string.

## Examples

``` r
qsf_path <- system.file("extdata", "demo_simple_linear.qsf",
                        package = "surveyBurden")
summary_line(burden_report(qsf_path))
#> ℹ Reading survey
#> ✔ Reading survey [5ms]
#> 
#> ℹ Scoring questions and working out routes
#> ✔ Scoring questions and working out routes [26ms]
#> 
#> ℹ Checking calculation certainty
#> ✔ Checking calculation certainty [17ms]
#> 
#> ℹ Working through display-logic combinations
#> ✔ Working through display-logic combinations [14ms]
#> 
#> [1] "Median burden: 40 GfS+ points (range 40-40 across 1 complete route). Expected duration in minutes: ~3 (range 3-3). Relative to benchmark: 0.1x the median of 399 points."
```
