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
  parsed_dl = NULL,
  max_condition_states = 10000L,
  overrides = NULL,
  choice_tasks = NULL,
  field_domains = NULL,
  loop_weights = NULL,
  respect_force_response = TRUE
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

- max_condition_states:

  Maximum joint condition-state combinations enumerated in full per
  connected display-logic component (default 10000). Must be a positive
  finite whole number. Larger components use the primary-gate
  approximation. This is separate from `max_paths` and does not remove
  other modelling assumptions. When precomputed results are supplied,
  use the same limit that generated those results.

- overrides:

  Optional named numeric vector of GfS+ points that replace the computed
  score of the named questions, e.g. `c(QID51 = 10)`. See
  [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md).
  Ignored, with a warning, when `engine` is supplied.

- choice_tasks:

  Optional data frame declaring stated-choice tasks (`question_id`,
  `n_alternatives`, `n_attributes`), scored by the GfS stated-choice
  rule. See
  [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md).
  Ignored, with a warning, when `engine` is supplied.

- field_domains:

  Optional named list giving the values an embedded-data field can hold,
  e.g. `list(SP_05 = 0:5)`. Passed to
  [`resolve_flow()`](https://pmpk20.github.io/surveyBurden/reference/resolve_flow.md).
  Ignored, with a warning, when `engine` is supplied.

- loop_weights:

  Optional named list of loop-count weights, keyed by Loop & Merge block
  id: a non-negative numeric vector with one weight per iteration count
  `1..max` (normalised internally), or a function of the component's
  shared-gate states returning such a vector. `NULL` (default) weights
  each count equally, e.g. `list(BL_x = c(1, 1, 1, 9))`.

- respect_force_response:

  If `TRUE` (default), a display-logic trigger that the route shows and
  whose response is forced (`ForceResponse = "ON"`) has no unanswered
  state, when its referenced choices cover all its choices. `FALSE`
  gives the 0.2.0 behaviour.

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
population; for that, use response data with
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md).
[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
pools the complete paths' profiles, so each complete path carries equal
total weight there.

Each display-logic trigger is a *gate*: a single-choice question
contributes its referenced choices as mutually exclusive states; a
multi-select contributes the subsets of its referenced choices; a stored
(embedded data) field contributes one state per distinguishable value
class of the comparisons made on it (each referenced value, the ranges
between thresholds, any other value, empty), so conditions on different
values of one field are mutually exclusive; a comparison the package
cannot evaluate (such as `Contains`) is a free true/false gate; a Loop &
Merge block contributes iteration counts `1..max`. Conditional questions
are grouped into coupling components (two questions couple if they share
a gate, directly or through a chain of shared gates). A component with
at most `max_condition_states` joint gate-states is **enumerated
exactly** – every joint combination of its gates' states, respecting
single-choice mutual exclusion and AND-across-gates conditions
precisely. A component above that (many questions sharing one popular
trigger, such as employment status) falls back to a primary-gate
approximation for just that component: each question is scored against
its first gate with the rest held permissive. Components are independent
of each other and their contributions convolved into the profile for the
path.

Loop & Merge blocks: display logic inside a loop is evaluated. A trigger
in the same loop block takes a fresh, equally weighted state in each
iteration (iterations are independent); a trigger outside the block
(another question or a stored field) keeps one state for every iteration
and is shared with non-loop questions that use it; a `LoopAndMerge`
"Loop k ... Current Loop" condition is evaluated from the iteration
index. Iteration counts `1..max` are weighted by `loop_weights` (equal
by default). A trigger question whose own condition fails is treated as
unanswered, so a question never appears because of an answer to a
question that was not shown. A trigger in a different loop block is
treated as shared and reported by the engine as unresolved.

Remaining approximations: different components are treated as
independent (the real coupling between, say, employment status and
having a licence is weak, but not checked); components above the chosen
state limit use the primary-gate approximation above. Once a path's
convolved profile exceeds 3000 distinct burden values it is re-binned to
multiples of 5 GfS points, so on a very heavy survey the reported
quantiles can move a few points from the fine-grained figure.

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
#> 3       3        103           121        143
#> 4       4        103           119        139
# }
```
