# Structural burden profile across a path's display-logic sub-states

[`path_burden()`](https://pmpk20.github.io/surveyBurden/reference/path_burden.md)
returns a floor/ceiling band per flow path. This function goes inside
the band and enumerates it.

## Usage

``` r
path_burden_profile(qsf, weights = gfs_weights(), max_paths = 10000L)
```

## Arguments

- qsf:

  A `qsf_raw` object.

- weights:

  A
  [`gfs_weights()`](https://pmpk20.github.io/surveyBurden/reference/gfs_weights.md)
  list.

- max_paths:

  Passed to
  [`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md).

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html), one row
per flow path: `path_id`, `terminates_early`, `n_gates`, `burden_min`,
`burden_p25`, `burden_median`, `burden_p75`, `burden_max` (unweighted
order statistics of the profile), and list column `profile`
(`tibble(burden, weight)` – `weight` is a count of sub-states, not a
probability).

## Details

This function returns the **structural burden profile**: every burden
value the path's display logic can produce, each counted once. It is not
a probability distribution. The quantiles below are unweighted order
statistics over the enumerated sub-states, not percentiles of a
respondent population. A real population average needs observed route
frequencies; see
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
for that.

Each display-logic trigger is a *gate*: a single-choice question
contributes its referenced choices as mutually exclusive states; a
multi-select or embedded field contributes binary states; a Loop & Merge
block contributes iteration counts `1..max`. Conditional questions are
grouped into coupling components (two questions couple if they share a
gate, directly or through a chain of shared gates). **Small components
are enumerated exactly** – every joint combination of their gates'
states, respecting single-choice mutual exclusion and AND-across-gates
conditions precisely. Components too large to enumerate (many questions
sharing one popular trigger, such as employment status) fall back to a
primary-gate approximation for just that component: each question is
scored against its first gate with the rest held permissive. Components
are independent of each other and their contributions convolved into the
profile for the path.

Remaining approximations: different components are treated as
independent (the real coupling between, say, employment status and
having a licence is weak, but not checked); large components use the
primary-gate approximation above; loop iterations are scored at a flat
per-iteration burden (within-loop display logic ignored).
