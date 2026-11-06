# Burden by block for each structural traversal of the survey

[`path_burden_profile()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_profile.md)
returns each route's burden distribution as a total. This function
returns the traversals behind it: one row per traversal and block, with
points, items, response items and pages, so that burden can be
accumulated through the survey from the same weighted traversals as the
total.

## Usage

``` r
path_burden_traversals(
  qsf,
  method = c("auto", "exact", "sample"),
  n_draws = 10000L,
  seed = 1L,
  loop_weights = NULL,
  field_rules = NULL,
  complete_only = TRUE,
  scheme = gfs_scheme(),
  max_paths = 10000L,
  max_traversals = 1e+05,
  overrides = NULL,
  choice_tasks = NULL,
  field_domains = NULL,
  respect_force_response = TRUE,
  output = c("long", "wide", "summary"),
  probs = c(0, 0.1, 0.25, 0.5, 0.75, 0.9, 1),
  chunk = 10000L
)
```

## Arguments

- qsf:

  A `qsf_raw` object or a path accepted by
  [`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md).

- method:

  `"auto"`, `"exact"` or `"sample"`.

- n_draws:

  Traversals sampled per route.

- seed:

  Random seed for sampling. The global random-number state is restored
  afterwards.

- loop_weights:

  Optional named list of loop-count weights, keyed by Loop & Merge block
  id: a non-negative numeric vector with one weight per iteration count
  `1..max` (normalised internally), or a function of the component's
  shared-gate states returning such a vector. `NULL` (default) weights
  each count equally, e.g. `list(BL_x = c(1, 1, 1, 9))`.

- field_rules:

  Optional named list of derivation rules (see Details).

- complete_only:

  Only routes that complete the survey (default).

- scheme:

  A
  [`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
  list.

- max_paths:

  Passed to
  [`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md).

- max_traversals:

  Largest number of traversals per route that `"exact"` enumerates.

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

- respect_force_response:

  If `TRUE` (default), a display-logic trigger that the route shows and
  whose response is forced (`ForceResponse = "ON"`) has no unanswered
  state, when its referenced choices cover all its choices. `FALSE`
  gives the 0.2.0 behaviour.

- output:

  `"long"` (one row per traversal and route block), `"wide"` (one row
  per traversal, one points column per survey block) or `"summary"`
  (weighted quantiles only; draws are not kept).

- probs:

  Quantile probabilities for `output = "summary"`.

- chunk:

  Draws simulated at a time when sampling.

## Value

For `"long"`, a tibble with `traversal_id`, `path_id`, `weight`,
`block_id`, `flow_order` (the block's position in the survey flow),
`iterations` (`NA` outside loops), `points`, `items`, `response_items`
and `pages`. For `"summary"`, a list with `totals` (weighted quantiles
of the traversal totals of points, response items and pages) and
`cumulative` (weighted quantiles of points accumulated through the
survey's blocks in flow order; blocks a route skips add zero). All
outputs carry attributes `method`, `rejected`, `unresolved`, `seed`,
`n_draws` and `convention`.

## Details

A traversal walks a route in flow order. A question is shown if the
route always shows it, or if its display logic holds given the answers
drawn so far. A trigger question gets a state only when it is shown:
hidden means unanswered; shown with a forced response
(`ForceResponse = "ON"`, when `respect_force_response = TRUE`) means
answered; otherwise answered or unanswered. Each state of a trigger, and
each iteration count of a Loop & Merge block (`loop_weights`, equal by
default), is a branch. Inside a loop, triggers in the same block are
drawn afresh in each iteration; other triggers keep one state.

**Weights.** Every route has equal total weight. With `method = "exact"`
every branch combination is enumerated and weighted by the product of
its branch weights, so the weights reproduce the structural convention
of
[`path_burden_profile()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_profile.md).
With `method = "sample"`, `n_draws` traversals are drawn per route
(stratified by route), each with weight `1 / (n_routes * n_draws)`.
`"auto"` enumerates when the number of traversals is at most
`max_traversals`, and samples otherwise. The method used per route is in
`attr(x, "method")`. These are model weights, not observed frequencies.

**Derived fields.** `field_rules` derives stored fields from the answers
drawn in a traversal, for values that survey code (for example page
JavaScript) computes and the survey file does not record. Each element,
named by its target (`"@Field"` for a stored field, `"@n:<BL_id>"` for a
loop's iteration count), is a function of the traversal state, or
`list(fun = , inputs = )` naming questions the rule reads that are not
display-logic triggers (these are then drawn when shown: every choice,
plus unanswered unless forced). In the state, a loop question's answer
in iteration `j` is `"<QID>#<j>"` and a loop count is `"@n:<BL_id>"`. A
derived field is never enumerated; its value is set before any display
logic that reads it. A rule returning `NA` rejects the traversal: exact
weights are renormalised within the route, rejected draws are redrawn,
and the rejected share per route is in `attr(x, "rejected")`. A
loop-count rule requires sampling.

**Speed.** A rule is called once per distinct combination of its inputs,
and results are reused across chunks and routes. Rules with many inputs
(for example an answer in each of ten loop iterations) are faster when
vectorised: `list(fun = , inputs = , vectorised = TRUE)` calls `fun`
once per chunk with whole columns (`""` for unanswered, choice ids
otherwise; loop counts as integers, `NULL` when the route has no such
loop) and expects one value per traversal.

Differences from
[`path_burden_profile()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_profile.md):
no primary-gate approximation; a conditionally shown forced trigger
never has an unanswered state; and `field_rules` apply. Without these,
exact traversal quantiles equal the profile's.

## Examples

``` r
# \donttest{
q <- read_qsf(system.file("extdata", "demo_travel_survey.qsf",
                          package = "surveyBurden"))
x <- path_burden_traversals(q, method = "exact")
head(x)
#> # A tibble: 6 × 10
#>   traversal_id path_id  weight block_id flow_order iterations points items
#>          <int>   <int>   <dbl> <chr>         <int>      <int>  <dbl> <int>
#> 1            1       3 0.00139 BL1               1         NA     11     1
#> 2            1       3 0.00139 BL2               2         NA      1     1
#> 3            1       3 0.00139 BL3               3         NA      2     1
#> 4            1       3 0.00139 BL4               4         NA     15     5
#> 5            1       3 0.00139 BL5               5         NA      3     2
#> 6            1       3 0.00139 BL6               6          1      4     2
#> # ℹ 2 more variables: response_items <int>, pages <int>
# }
```
