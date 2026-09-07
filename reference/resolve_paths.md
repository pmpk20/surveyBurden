# Resolve respondent paths, flow *and* display logic

Combines
[`resolve_flow()`](https://pmpk20.github.io/surveyBurden/reference/resolve_flow.md)
(block-level routing) with a within-block display-logic reachability
analysis. For each flow path it partitions the questions into those
always shown, those that *may* be shown (a display-logic condition we
cannot evaluate ex ante), and those that can never be shown on that path
(the condition's trigger question is not on the path).

## Usage

``` r
resolve_paths(qsf, max_paths = 10000L)
```

## Arguments

- qsf:

  A `qsf_raw` object from
  [`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md).

- max_paths:

  Passed to
  [`resolve_flow()`](https://pmpk20.github.io/surveyBurden/reference/resolve_flow.md).

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html), one row
per flow path, with the
[`resolve_flow()`](https://pmpk20.github.io/surveyBurden/reference/resolve_flow.md)
columns plus:

- q_always:

  List column: question ids shown on every visit to this path.

- q_maybe:

  List column: question ids gated by an unresolved condition.

- n_gates:

  Distinct root trigger questions active on this path.

## Details

Interior enumeration of the display-logic state space is **not**
performed: a large instrument can carry dozens of root display-logic
gates with choice-level mutual exclusivity, which needs a constraint
solver. The honest output is the structural band per path (floor =
always, ceiling = always + maybe); see
[`path_burden()`](https://pmpk20.github.io/surveyBurden/reference/path_burden.md).
