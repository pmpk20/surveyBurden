# Monte Carlo stability of sampled traversal quantiles across seeds

Reruns
[`path_burden_traversals()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_traversals.md)
with `method = "sample"` for each seed and reports the weighted 10th,
50th and 90th percentiles of the traversal totals (GfS+ points), with
their range across seeds.

## Usage

``` r
traversal_stability(qsf, seeds = 1:5, n_draws = 10000L, ...)
```

## Arguments

- qsf:

  As in
  [`path_burden_traversals()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_traversals.md).

- seeds:

  Seeds to run.

- n_draws:

  Draws per route per seed.

- ...:

  Passed to
  [`path_burden_traversals()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_traversals.md).

## Value

A list: `per_seed` (tibble `seed`, `p10`, `median`, `p90`) and `range`
(tibble with rows `min`, `max`, `spread`).

## Examples

``` r
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                        package = "surveyBurden")
traversal_stability(qsf_path, seeds = 1:2, n_draws = 200)
#> $per_seed
#> # A tibble: 2 × 4
#>    seed   p10 median   p90
#>   <int> <dbl>  <dbl> <dbl>
#> 1     1   110    120   130
#> 2     2   109    120   131
#> 
#> $range
#> # A tibble: 3 × 4
#>   stat     p10 median   p90
#>   <chr>  <dbl>  <dbl> <dbl>
#> 1 min      109    120   130
#> 2 max      110    120   131
#> 3 spread     1      0     1
#> 
```
