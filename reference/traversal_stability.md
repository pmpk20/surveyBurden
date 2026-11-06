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
