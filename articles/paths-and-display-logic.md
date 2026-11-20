# Paths and display logic

**What this answers.** How the paths through a survey are reconstructed,
and what the structural profile’s weights mean.

**What you need.** A `.qsf`.

**What to keep in mind.** The structural profile weights the survey’s
design, and response data gives the distribution across respondents. The
package treats each branch condition on its own, so the profile’s
extremes may come from routes whose conditions contradict each other.

This article covers how surveyBurden reconstructs the paths through a
survey and turns them into a burden spread. It also explains how the
structural profile differs from respondent burden. For per-question
scoring see
[`vignette("gfs-scoring")`](https://pmpk20.github.io/surveyBurden/articles/gfs-scoring.md),
and for the printed output see
[`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md).

``` r

library(surveyBurden)
#> 
#>                   .-- Q2 -- Q3 --.
#>   survey -- Q1 --+               +-- Burden 0.3.1
#>                   '-- Q4 --------'
#> 
#> Measuring the Response Burden of Web Surveys
#> Docs: https://pmpk20.github.io/surveyBurden/
#> 
#> Please cite: King P (2026). surveyBurden: Measuring the Response Burden
#> of Web Surveys. R package version 0.3.1,
#> https://github.com/pmpk20/surveyBurden.
#> Use citation("surveyBurden") for BibTeX.
demo <- system.file("extdata", "demo_travel_survey.qsf", package = "surveyBurden")
qsf <- read_qsf(demo)
report <- burden_report(demo, quiet = TRUE)
```

## Survey flow

Modern web surveys route respondents through different sequences of
blocks.
[`resolve_flow()`](https://pmpk20.github.io/surveyBurden/reference/resolve_flow.md)
walks the `SurveyFlow`. At every `Branch` it forks into a continuation
where the condition holds and one where it fails, and at every
`EndSurvey` it forks into a screen-out. Most branch conditions depend on
embedded data or earlier answers that only fieldwork reveals, so both
outcomes are kept.

Branches that compare one embedded field with a value (`=`, `!=`, `>`,
`>=`, `<`, `<=`) are handled differently. The field holds one value
along a path, so every branch on it agrees with that value, and a fixed
value set earlier in the flow (including one a randomiser picks) decides
the branch. A run of equality tests on one field (“`group` is 1”,
“`group` is 2”, …) becomes one path per value plus a “none matches”
path, because the field could hold any value. When you know the values a
field can hold, declare them.

``` r

burden_report(qsf, field_domains = list(group = c("1", "2")))
```

The package then keeps the “none matches” path only when a declared
value matches no branch. The result is every block sequence a respondent
could encounter.

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

A block randomiser that shows `m` of its `M` elements (“present 1 of 3
blocks”) becomes one path per combination of elements, each in survey
order, because order leaves burden unchanged. With even presentation
each combination is equally likely, which matches the equal weight each
path gets. When the number shown is unreadable, every element is treated
as shown, with a warning. A randomiser holding only embedded-data
assignments shows no blocks itself. It adds paths only when a later
branch tests a field it sets (one path per value it can assign). The
package enumerates paths up to `max_paths` (10000), and a flow that
would produce more raises an error instead of returning a partial
answer.

## Display logic

Within a path,
[`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md)
splits the questions into three sets.

- **Always shown.**
- **May be shown**, gated by a condition that depends on fieldwork.
- **Never shown on this path**, because the gate’s trigger question is
  absent from this path.

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

Qualtrics stores display logic as `If` / `ElseIf` / `AndIf` groups. The
package folds each group left to right. It combines `ElseIf` clauses
with OR and `AndIf` clauses with AND, and treats a missing type as AND.
Keeping the OR clauses matters, because a question can appear when any
one of several conditions holds.

## Path enumeration

[`path_burden_profile()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_profile.md)
works inside the “may be shown” set and enumerates the display-logic
states the package can model.

- Conditional questions are grouped into **coupling components**. Two
  questions couple if they share a gate, directly or through a chain of
  shared gates.
- A component with at most `max_condition_states` (default 10000) joint
  gate states is enumerated **in full**. Every joint state of its gates
  that the model represents is included, respecting single-choice mutual
  exclusion and conditions joined by AND across gates. A stored
  (embedded data) field compared with `EqualTo`, `NotEqualTo` or an
  inequality is enumerated over its distinguishable values, so
  conditions on different values of one field are mutually exclusive.
  “In full” means exhaustive within the model. A field compared with any
  other operator is treated as a free true/false condition, and branch
  conditions and display logic are enumerated separately.
- A larger component (dozens of questions keyed off one popular trigger
  such as employment status) uses a **primary-gate approximation**. Each
  question is scored against its first gate, and its other gates are
  treated as passed.
- Separate components are combined as independent.
- Loop & Merge blocks are unrolled to the explicit `?v=N` cap. The
  structural profile treats the iteration count as uniform over 1 to N,
  unless `loop_weights` gives other weights (for example
  `loop_weights = list(BL_x = c(1, 1, 1, 9))`).
- Display logic inside a loop is evaluated. A trigger in the same loop
  block is answered afresh in each iteration. A trigger outside the
  block (an earlier question or a stored field) has one answer for every
  iteration, shared with any question outside the loop that uses it. A
  “Loop 1 … Current Loop” condition holds in the first iteration only.
- A hidden trigger question stays unanswered, so every question it gates
  stays hidden too. A shown trigger with a forced response is always
  answered (`respect_force_response = TRUE`, the default).

``` r

pbp <- path_burden_profile(qsf)
pbp[, c("path_id", "terminates_early", "burden_min",
        "burden_median", "burden_max")]
#> # A tibble: 4 × 5
#>   path_id terminates_early burden_min burden_median burden_max
#>     <int> <lgl>                 <dbl>         <dbl>      <dbl>
#> 1       1 TRUE                     12            12         12
#> 2       2 TRUE                     14            14         14
#> 3       3 FALSE                   103           121        143
#> 4       4 FALSE                   103           119        139
nrow(pbp$profile[[3]])   # distinct modelled burden values on complete path 3
#> [1] 41
```

Each row of a `profile` table is one modelled burden value with a
structural weight. Each joint gate state and each loop iteration count
gets equal weight, a value produced by several states carries their
combined weight, and the weights on a path sum to 1. **That weight comes
from the model of the design.** Respondent shares come from response
data.

### Burden by block for each traversal

[`path_burden_traversals()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_traversals.md)
returns the traversals behind the profile, with one row per traversal
and block giving points, items, response items and pages. A
cumulative-by-block curve and the totals therefore come from the same
weighted traversals. Small surveys are enumerated exactly, and larger
ones are sampled with a fixed seed
([`traversal_stability()`](https://pmpk20.github.io/surveyBurden/reference/traversal_stability.md)
reports the spread across seeds). `field_rules` can derive stored fields
that survey code computes and the survey file leaves out.

``` r

tr <- path_burden_traversals(qsf, method = "exact")
head(tr[, c("traversal_id", "path_id", "weight", "block_id", "points")])
#> # A tibble: 6 × 5
#>   traversal_id path_id  weight block_id points
#>          <int>   <int>   <dbl> <chr>     <dbl>
#> 1            1       3 0.00139 BL1          11
#> 2            1       3 0.00139 BL2           1
#> 3            1       3 0.00139 BL3           2
#> 4            1       3 0.00139 BL4          15
#> 5            1       3 0.00139 BL5           3
#> 6            1       3 0.00139 BL6           4
```

## Structural and respondent burden

This distinction is central, and it is easy to state wrongly.

The default result is a **structural burden profile**. It covers the
combinations of optional questions the package can model, weighted by
the model. Each complete path carries equal total weight, and within a
path each modelled combination does. When the report says the median is
120 points, it means the median of that model-weighted distribution. How
common each path or combination is among respondents is a separate
question, which only response data can answer.

For a distribution across respondents, supply response data.
`burden_report(qsf, responses = ...)` adds `$respondents`, the quantiles
and mean of respondent burden over complete responses. Each respondent
counts once, so paths taken by more respondents carry more weight. See
[`vignette("respondent-burden")`](https://pmpk20.github.io/surveyBurden/articles/respondent-burden.md)
for the measure and the data it needs.

## Next

- [`vignette("respondent-burden")`](https://pmpk20.github.io/surveyBurden/articles/respondent-burden.md)
  measures respondent burden from response data.
- [`vignette("calibration")`](https://pmpk20.github.io/surveyBurden/articles/calibration.md)
  checks respondent burden against completion times.
