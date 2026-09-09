# Paths and display logic

This article covers how surveyBurden reconstructs the routes through a
survey and turns them into a burden spread, and the difference between
the structural profile and a population-weighted average. For
per-question scoring see
[`vignette("gfs-scoring")`](https://pmpk20.github.io/surveyBurden/articles/gfs-scoring.md);
for the printed output see
[`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md).

``` r

library(surveyBurden)
demo <- system.file("extdata", "demo_travel_survey.qsf", package = "surveyBurden")
qsf <- read_qsf(demo)
report <- burden_report(demo, quiet = TRUE)
```

## Survey flow

Contemporary web surveys are not a fixed sequence.
[`resolve_flow()`](https://pmpk20.github.io/surveyBurden/reference/resolve_flow.md)
walks the `SurveyFlow`, forking at every `Branch` into a condition-true
and a condition-false continuation, and at every `EndSurvey` into a
screen-out. Branch conditions are **not evaluated** – they depend on
embedded data or prior answers that are unknown before fielding – so
both outcomes are always kept. The result is every block sequence a
respondent could encounter.

``` r

resolve_flow(qsf)
#> # A tibble: 4 × 4
#>   path_id block_ids  terminates_early decisions
#>     <int> <list>     <lgl>            <list>   
#> 1       1 <chr [2]>  TRUE             <lgl [1]>
#> 2       2 <chr [3]>  TRUE             <lgl [2]>
#> 3       3 <chr [12]> FALSE            <lgl [3]>
#> 4       4 <chr [11]> FALSE            <lgl [3]>
```

``` r

nrow(report$paths)
#> [1] 4
sum(report$paths$status == "complete")
#> [1] 2
sum(report$paths$status == "screen_out")
#> [1] 2
```

Block randomisers are treated as “all sub-blocks shown, in survey order”
– the randomised subsets are not enumerated. The path space is
enumerated up to `max_paths` (10000); a flow that would produce more
raises an error rather than a partial answer.

## Display logic

Within a path,
[`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md)
partitions the questions into three sets: **always shown**, **may be
shown** (gated by a condition that cannot be evaluated before fielding),
and **never shown on this path** (the gate’s trigger question is not on
the path).

``` r

rp <- resolve_paths(qsf)
data.frame(
  path_id    = rp$path_id,
  screen_out = rp$terminates_early,
  n_always   = lengths(rp$q_always),
  n_maybe    = lengths(rp$q_maybe),
  n_gates    = rp$n_gates
)
#>   path_id screen_out n_always n_maybe n_gates
#> 1       1       TRUE        2       0       0
#> 2       2       TRUE        3       0       0
#> 3       3      FALSE       20       6       4
#> 4       4      FALSE       20       3       3
```

Qualtrics display logic is stored as `If` / `ElseIf` / `AndIf` groups.
The package folds each group left to right: `ElseIf` clauses combined
with OR, `AndIf` clauses with AND, a missing type falling back to AND.
Flattening everything to AND would under-count the cases where a
question appears if any one of several conditions holds.

## Path enumeration

[`path_burden_profile()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_profile.md)
goes inside the “may be shown” set and enumerates the feasible
display-logic states.

- Conditional questions are grouped into **coupling components**: two
  questions couple if they share a gate, directly or through a chain of
  shared gates.
- A component with at most 5000 joint gate-states is enumerated
  **exactly** – every joint state of its gates, respecting single-choice
  mutual exclusion and AND-across-gates conditions.
- A larger component (dozens of questions keyed off one popular trigger
  such as employment status) falls back to a **primary-gate
  approximation**: each question is scored against its first gate, the
  rest held permissive.
- Separate components are convolved as independent.
- Loop & Merge blocks are unrolled to the explicit `?v=N` cap, with the
  iteration count treated as uniform over 1 to N in the structural
  profile.

``` r

pbp <- path_burden_profile(qsf)
pbp[, c("path_id", "terminates_early", "burden_min",
        "burden_median", "burden_max")]
#> # A tibble: 4 × 5
#>   path_id terminates_early burden_min burden_median burden_max
#>     <int> <lgl>                 <dbl>         <dbl>      <dbl>
#> 1       1 TRUE                     12            12         12
#> 2       2 TRUE                     14            14         14
#> 3       3 FALSE                   106           124        143
#> 4       4 FALSE                   106           122        139
nrow(pbp$profile[[3]])   # feasible burden values on complete path 3
#> [1] 36
```

Each row of a `profile` table is one feasible burden value with a
structural weight from the gate combinatorics and the uniform
loop-iteration assumption. **That weight is not a respondent
probability.**

## Structural versus population-weighted burden

This distinction is central and is easy to state wrongly.

The default result is a **structural burden profile**. It lists every
feasible combination of optional questions once. It carries no
respondent probabilities. When the report says the median is 123 points,
it means the median across those feasible combinations. It does **not**
mean half of respondents face at least that much burden. Nobody has told
the package how common each combination is.

To get a real average over respondents you need observed routes. Give
[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
a data frame of respondents and it adds a **population-weighted
respondent burden**: the sum, over the observed routes, of each route’s
burden multiplied by how often that route occurred. Writing the observed
frequency of route k as w_k and its burden as B_k:

``` math
\bar{B} = \sum_k w_k \, B_k
```

The structural profile is what you have without the w_k. The
population-weighted result is what the w_k buy you.

The recognised route columns are `loop_<id>` (the iteration count for a
Loop & Merge block, keyed by its driving question id or block id) and
`visit_<block_id>` (`TRUE` to include a branch-gated optional block).
The demo has two loop blocks, `BL6` and `BL8`. A small constructed set
of 50 respondent routes:

``` r

set.seed(1)
routes <- data.frame(
  loop_BL6 = rbinom(50, 5, 0.4),   # "Other adults" loop, cap 5
  loop_BL8 = rbinom(50, 3, 0.5)    # "Vehicle details" loop, cap 3
)
burden_report(demo, routes = routes, quiet = TRUE)$population
#> # A tibble: 5 × 4
#>   statistic points minutes  index
#>   <fct>      <dbl>   <dbl>  <dbl>
#> 1 min         100     8.33 0.0667
#> 2 p25         110.    9.19 0.0735
#> 3 median      116     9.67 0.0773
#> 4 p75         122.   10.1  0.0812
#> 5 max         132    11    0.088
```

Real route data would come from a fielded response file, not from
[`rbinom()`](https://rdrr.io/r/stats/Binomial.html). When `routes` are
supplied the report’s verdict line also gives the population-weighted
median.

Without routes,
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
still gives a per-path table and
[`summary_line()`](https://pmpk20.github.io/surveyBurden/reference/summary_line.md)
turns it into a sentence:

``` r

summary_line(respondent_burden(demo))
#> [1] "Typical respondent burden is about 118 GfS points (~10 min). The lightest complete route is ~117 pts (~10 min); with the Loop & Merge sections fully repeated it reaches ~143 pts (~12 min)."
```
