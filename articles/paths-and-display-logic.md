# Paths and display logic

**What this answers.** How the routes through a survey are
reconstructed, what the structural profile’s weights mean, and how to
get respondent-level predictions from route data.

**What you need.** A `.qsf`; for respondent-level predictions, routes
derived from response data (recipe below).

**What it cannot establish.** The structural profile is not a respondent
distribution; branch conditions are not checked against each other, so
its extremes may be unreachable; and `matched = TRUE` does not certify a
respondent’s loop counts or display-logic answers.

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
#> 3       3 FALSE                   106           124        143
#> 4       4 FALSE                   106           122        139
nrow(pbp$profile[[3]])   # distinct modelled burden values on complete path 3
#> [1] 36
```

Each row of a `profile` table is one modelled burden value with a
structural weight: each joint gate state and each loop iteration count
gets equal weight, a value produced by several states carries their
combined weight, and the weights on a path sum to 1. **That weight is a
model weight, not a respondent probability.**

## Structural versus population-weighted burden

This distinction is central and is easy to state wrongly.

The default result is a **structural burden profile**. It covers the
combinations of optional questions the package can model, weighted by
the model: each complete path carries equal total weight, and within a
path each modelled combination does. It carries no respondent
probabilities. When the report says the median is 123 points, it means
the median of that model-weighted distribution. It does **not** mean
half of respondents face at least that much burden. Nobody has told the
package how common each path or combination is.

To move from the structural profile to respondent-level predictions,
pass a data frame of respondent routes to
[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
via the `routes` argument. The package then:

1.  **Matches** each respondent to a flow path, using their `visit_*`
    columns (which branch-gated blocks they entered).
2.  **Predicts** each respondent’s burden from their actual loop
    iteration counts and the median display-logic burden on their
    matched path.
3.  **Summarises** by taking quantiles (min, p25, median, p75, max)
    across the vector of per-respondent predictions. The result appears
    as `$population` in the report.

Routes taken by more respondents naturally dominate the quantiles, so
the result reflects the empirical distribution of burden across your
sample — but it is straight quantiles of individual predictions, not a
route-frequency-weighted formula.

### Required columns

The data frame has one row per respondent. Every column is optional;
missing columns get defaults.

| Column | Type | Meaning | Default |
|----|----|----|----|
| `loop_<QID>` or `loop_<BL>` | integer | Iteration count for a Loop & Merge block, keyed by its driving question id or block id | `loop_typical` (default 2) |
| `visit_<block_id>` | logical | `TRUE` if the respondent entered this branch-gated optional block | `FALSE` (block skipped) |

How values are read:

- `loop_*`: `0` (or less) means the loop was never entered; a count
  above the block’s cap is capped; `NA` – like a missing column – means
  “unknown” and uses `loop_typical`. Use `0`, not `NA`, for “did not
  loop”.
- `visit_*`: read with
  [`as.logical()`](https://rdrr.io/r/base/logical.html), so `TRUE` / `1`
  / `"TRUE"` count as visited; `FALSE`, `NA` and anything else
  (including `"yes"`) count as not visited.

Any `loop_*` column that does not match a known question or block id is
assigned to loop blocks in flow order — so a generic `loop_1`, `loop_2`
also works if the survey has two loops in sequence.

### Example

The demo survey has two Loop & Merge blocks, `BL6` and `BL8`. A small
constructed set of 50 respondent routes:

``` r

set.seed(1)
routes <- data.frame(
  loop_BL6 = rbinom(50, 5, 0.4),   # "Other adults" loop, cap 5
  loop_BL8 = rbinom(50, 3, 0.5)    # "Vehicle details" loop, cap 3
)
burden_report(demo, routes = routes, quiet = TRUE)$population
#> # A tibble: 8 × 4
#>   statistic points minutes  index
#>   <fct>      <dbl>   <dbl>  <dbl>
#> 1 min         100     8.33 0.0667
#> 2 p10         105     8.75 0.07  
#> 3 p25         110.    9.19 0.0735
#> 4 median      116     9.67 0.0773
#> 5 mean        114.    9.52 0.0761
#> 6 p75         122.   10.1  0.0812
#> 7 p90         122.   10.2  0.0814
#> 8 max         132    11    0.088
```

When `routes` are supplied the report’s verdict line also gives the
population-weighted median.

### Building routes from a response export

Real routes come from your fielded response file: flag which optional
blocks each respondent answered in, and count their loop iterations.
Here a toy export stands in for yours; it uses `QID`-named columns with
loop iterations prefixed `1_`, `2_`, … (what
`qualtRics::fetch_survey(label = FALSE)` gives). Remove the two
Qualtrics header rows first if you read a raw CSV (see
[`vignette("realised-burden")`](https://pmpk20.github.io/surveyBurden/articles/realised-burden.md)).

``` r

qsf    <- read_qsf(demo)
cat    <- parse_qsf(qsf)
blocks <- resolve_live_blocks(qsf)

# toy export: respondents 1-3 answer the core questions; 1-2 enter the loops
resp <- data.frame(ResponseId = paste0("R_", 1:4))
for (q in cat$question_id[!cat$in_loop]) resp[[q]] <- c("1", "1", "1", NA)
for (q in cat$question_id[cat$in_loop]) {
  resp[[paste0("1_", q)]] <- c("1", "1", NA, NA)
  resp[[paste0("2_", q)]] <- c("1", NA, NA, NA)
}

# 1. which question, and which loop iteration, each column belongs to
cols   <- grep("QID[0-9]+", names(resp), value = TRUE)
col_q  <- regmatches(cols, regexpr("QID[0-9]+", cols))
col_it <- rep(0L, length(cols))
pre    <- grepl("^[0-9]+_QID", cols)
col_it[pre] <- as.integer(sub("_.*$", "", cols[pre]))
filled <- vapply(resp[cols], function(v) !is.na(v) & nzchar(trimws(v)),
                 logical(nrow(resp)))

routes <- data.frame(ResponseId = resp$ResponseId)

# 2. visit_<block>: answered anything in each branch-gated optional block
optional <- unique(unlist(respondent_burden(qsf)$optional_blocks))
for (bid in optional) {
  in_blk <- col_q %in% blocks$question_ids[[match(bid, blocks$block_id)]]
  routes[[paste0("visit_", bid)]] <- rowSums(filled[, in_blk, drop = FALSE]) > 0
}

# 3. loop_<block>: highest iteration with any answer; 0 = never entered
for (i in which(blocks$in_loop)) {
  in_blk <- col_q %in% blocks$question_ids[[i]]
  it <- sweep(filled[, in_blk, drop = FALSE], 2, col_it[in_blk], `*`)
  routes[[paste0("loop_", blocks$block_id[i])]] <- apply(it, 1, max, 0)
}
routes
#>   ResponseId visit_BL11 loop_BL6 loop_BL8
#> 1        R_1       TRUE        2        2
#> 2        R_2       TRUE        1        1
#> 3        R_3       TRUE        0        0
#> 4        R_4      FALSE        0        0
```

This infers routes from answers, so it shares the limits of
[`realised_burden()`](https://pmpk20.github.io/surveyBurden/reference/realised_burden.md):
a block a respondent was shown but answered nothing in looks unvisited,
and a loop iteration left blank is not counted.

### Checking routes before summarising

Check the match before reading `$population`:

``` r

pr <- respondent_burden(qsf, routes = routes)
pr[, c("ResponseId", "path_id", "matched", "pred_pts")]
#> # A tibble: 4 × 4
#>   ResponseId path_id matched pred_pts
#>   <chr>        <int> <lgl>      <dbl>
#> 1 R_1              3 TRUE         119
#> 2 R_2              3 TRUE         108
#> 3 R_3              3 TRUE          97
#> 4 R_4              4 TRUE          95
table(pr$matched)
#> 
#> TRUE 
#>    4
```

`matched = TRUE` certifies only that the respondent’s set of visited
optional blocks equals the set on one enumerated complete path. It does
not check their loop counts, their display-logic answers, or that the
branch conditions for that path were actually met. `matched = FALSE`
means no enumerated path has that set; the prediction then falls back to
another path and a warning says which, so treat those rows as suspect
(often a sign of a route-encoding mistake, or of a flow the model does
not represent). Note that a respondent who answered nothing, like `R_4`
here, still matches the path with no optional blocks; filter such rows
(or non-finishers) out first if they should not count.

Without routes,
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
still gives a per-path table and
[`summary_line()`](https://pmpk20.github.io/surveyBurden/reference/summary_line.md)
turns it into a sentence:

``` r

summary_line(respondent_burden(demo))
#> [1] "Typical respondent burden is about 118 GfS+ points (~10 min). The lightest complete route is ~117 pts (~10 min); with the Loop & Merge sections fully repeated it reaches ~143 pts (~12 min)."
```

## Next

- [`vignette("realised-burden")`](https://pmpk20.github.io/surveyBurden/articles/realised-burden.md)
  – answer-based burden from response data.
- [`vignette("calibration")`](https://pmpk20.github.io/surveyBurden/articles/calibration.md)
  – checking predictions against completion times.
