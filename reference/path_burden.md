# Burden per survey path

Joins
[`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md)
to
[`score_burden()`](https://pmpk20.github.io/surveyBurden/reference/score_burden.md)
and reports, for every flow path, a burden band: the *floor* (only
always-shown questions, loop blocks run once) and the *ceiling* (every
reachable question, loop blocks run to their maximum). The true burden
of any actual respondent on that path lies between.

## Usage

``` r
path_burden(
  qsf,
  scheme = gfs_scheme(),
  max_paths = 10000L,
  paths = NULL,
  scored = NULL
)
```

## Arguments

- qsf:

  A `qsf_raw` object from
  [`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md).

- scheme:

  A
  [`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
  list.

- max_paths:

  Passed to
  [`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md).

- paths, scored:

  Optional precomputed
  [`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md)
  and
  [`score_burden()`](https://pmpk20.github.io/surveyBurden/reference/score_burden.md)
  results for this `qsf` (internal reuse; `NULL` computes them here,
  leaving the public behaviour unchanged).

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html), one row
per flow path: `path_id`, `terminates_early`, `n_blocks`, `n_q_floor`,
`n_q_ceiling`, `gfs_floor`, `gfs_ceiling`, `min_minutes`, `max_minutes`,
`n_gates`.

## Examples

``` r
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                         package = "surveyBurden")
pb <- path_burden(read_qsf(qsf_path))
pb[, c("path_id", "gfs_floor", "gfs_ceiling")]
#> # A tibble: 4 × 3
#>   path_id gfs_floor gfs_ceiling
#>     <int>     <dbl>       <dbl>
#> 1       1        12          12
#> 2       2        14          14
#> 3       3       103         145
#> 4       4       103         139
```
