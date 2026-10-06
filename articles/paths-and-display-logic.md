# Paths and display logic

**What this answers.** How the paths through a survey are reconstructed,
and what the structural profile’s weights mean.

**What you need.** A `.qsf`.

**What it cannot establish.** The structural profile is not a respondent
distribution; branch conditions are not checked against each other, so
its extremes may be unreachable.

This article covers how surveyBurden reconstructs the paths through a
survey and turns them into a burden spread, and the difference between
the structural profile and respondent burden. For per-question scoring
see
[`vignette("gfs-scoring")`](https://pmpk20.github.io/surveyBurden/articles/gfs-scoring.md);
for the printed output see
[`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md).

``` r

library(surveyBurden)
#> 
#>                   .-- Q2 -- Q3 --.
#>   survey -- Q1 --+               +-- Burden 0.2.0
#>                   '-- Q4 --------'
#> 
#> An R package for assessing the response-burden of web surveys
#> Docs: https://pmpk20.github.io/surveyBurden/
#> 
#> Please cite: King P (2026). surveyBurden: An R package for assessing
#> the response-burden of web surveys. R package version 0.2.0,
#> https://github.com/pmpk20/surveyBurden.
#> Use citation("surveyBurden") for BibTeX.
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
embedded data or prior answers that are unknown before fieldwork – so
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
shown** (gated by a condition that cannot be evaluated before
fieldwork), and **never shown on this path** (the gate’s trigger
question is not on the path).

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
goes inside the “may be shown” set and enumerates the display-logic
states the package can model.

- Conditional questions are grouped into **coupling components**: two
  questions couple if they share a gate, directly or through a chain of
  shared gates.
- A component with at most 5000 joint gate-states is enumerated **in
  full** – every joint state of its gates that the model represents,
  respecting single-choice mutual exclusion and AND-across-gates
  conditions. “In full” means exhaustive within the model; embedded-data
  conditions are still treated as free, and branch conditions are not
  checked against each other.
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
#> 3       3 FALSE                   106           125        143
#> 4       4 FALSE                   106           122        139
nrow(pbp$profile[[3]])   # distinct modelled burden values on complete path 3
#> [1] 36
```

Each row of a `profile` table is one modelled burden value with a
structural weight: each joint gate state and each loop iteration count
gets equal weight, a value produced by several states carries their
combined weight, and the weights on a path sum to 1. **That weight is a
model weight, not a respondent probability.**

## Structural versus respondent burden

This distinction is central and is easy to state wrongly.

The default result is a **structural burden profile**. It covers the
combinations of optional questions the package can model, weighted by
the model: each complete path carries equal total weight, and within a
path each modelled combination does. It carries no respondent
probabilities. When the report says the median is 123 points, it means
the median of that model-weighted distribution. It does **not** mean
half of respondents face at least that much burden. Nobody has told the
package how common each path or combination is.

For a distribution across respondents, supply response data:
`burden_report(qsf, responses = ...)` adds `$respondents`, quantiles and
the mean of respondent burden over complete responses. Each respondent
counts once, so paths taken by more respondents carry more weight. See
[`vignette("respondent-burden")`](https://pmpk20.github.io/surveyBurden/articles/respondent-burden.md)
for the measure and the data it needs.

## Next

- [`vignette("respondent-burden")`](https://pmpk20.github.io/surveyBurden/articles/respondent-burden.md)
  – respondent burden from response data.
- [`vignette("calibration")`](https://pmpk20.github.io/surveyBurden/articles/calibration.md)
  – checking respondent burden against completion times.
