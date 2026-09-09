# Burden per respondent path

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
  weights = gfs_weights(),
  max_paths = 10000L,
  paths = NULL,
  scored = NULL
)
```

## Arguments

- qsf:

  A `qsf_raw` object from
  [`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md).

- weights:

  A
  [`gfs_weights()`](https://pmpk20.github.io/surveyBurden/reference/gfs_weights.md)
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
