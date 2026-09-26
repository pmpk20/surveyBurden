# Structural burden profile across a path's display-logic sub-states

[`path_burden()`](https://pmpk20.github.io/surveyBurden/reference/path_burden.md)
returns a floor/ceiling band per flow path. This function goes inside
the band and enumerates it.

## Usage

``` r
path_burden_profile(
  qsf,
  scheme = gfs_scheme(),
  max_paths = 10000L,
  engine = NULL,
  parsed_dl = NULL
)
```

## Arguments

- qsf:

  A `qsf_raw` object.

- scheme:

  A
  [`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
  list.

- max_paths:

  Passed to
  [`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md).

- engine:

  Optional precomputed `burden_engine()` result for this `qsf` (internal
  reuse; `NULL` builds it here, leaving the public behaviour unchanged).

- parsed_dl:

  Optional precomputed map of parsed display-logic trees for this `qsf`
  (internal reuse by
  [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md);
  ignored when `engine` is supplied, computed as needed when `NULL`).

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html), one row
per flow path: `path_id`, `terminates_early`, `n_gates`, `burden_min`,
`burden_p25`, `burden_median`, `burden_p75`, `burden_max` (unweighted
order statistics of the profile), and list column `profile`
(`tibble(burden, weight)` – `weight` is a count of sub-states, not a
probability).

## Details

This function returns the **structural burden profile**: every burden
value the path's modelled display-logic states can produce, with a
weight. Each joint state of a component's gates (and each loop iteration
count `1..max`) gets equal weight, a burden value produced by several
states carries their combined weight, and each path's weights sum to 1.
The quantiles are weighted by these model weights. They are not observed
respondent frequencies, so they are not percentiles of a respondent
population; for that, use observed routes with
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md).
[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
pools the complete paths' profiles, so each complete path carries equal
total weight there.

Each display-logic trigger is a *gate*: a single-choice question
contributes its referenced choices as mutually exclusive states; a
multi-select or embedded field contributes binary states; a Loop & Merge
block contributes iteration counts `1..max`. Conditional questions are
grouped into coupling components (two questions couple if they share a
gate, directly or through a chain of shared gates). A component with at
most 5000 joint gate-states is **enumerated exactly** – every joint
combination of its gates' states, respecting single-choice mutual
exclusion and AND-across-gates conditions precisely. A component above
that (many questions sharing one popular trigger, such as employment
status) falls back to a primary-gate approximation for just that
component: each question is scored against its first gate with the rest
held permissive. Components are independent of each other and their
contributions convolved into the profile for the path.

Remaining approximations: different components are treated as
independent (the real coupling between, say, employment status and
having a licence is weak, but not checked); components above the
5000-state cap use the primary-gate approximation above; loop iterations
are scored at a flat per-iteration burden (within-loop display logic
ignored). Once a path's convolved profile exceeds 3000 distinct burden
values it is re-binned to multiples of 5 GfS points, so on a very heavy
survey the reported quantiles can move a few points from the
fine-grained figure.

## Examples

``` r
# \donttest{
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                         package = "surveyBurden")
pbp <- path_burden_profile(read_qsf(qsf_path))
pbp[, c("path_id", "burden_min", "burden_median", "burden_max")]
#> # A tibble: 4 × 4
#>   path_id burden_min burden_median burden_max
#>     <int>      <dbl>         <dbl>      <dbl>
#> 1       1         12            12         12
#> 2       2         14            14         14
#> 3       3        106           124        143
#> 4       4        106           122        139
# }
```
