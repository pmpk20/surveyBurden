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
resolve_paths(qsf, max_paths = 10000L, catalogue = NULL, blocks = NULL)
```

## Arguments

- qsf:

  A `qsf_raw` object from
  [`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md).

- max_paths:

  Passed to
  [`resolve_flow()`](https://pmpk20.github.io/surveyBurden/reference/resolve_flow.md).

- catalogue, blocks:

  Optional precomputed
  [`parse_qsf()`](https://pmpk20.github.io/surveyBurden/reference/parse_qsf.md)
  and
  [`resolve_live_blocks()`](https://pmpk20.github.io/surveyBurden/reference/resolve_live_blocks.md)
  results for this `qsf`. Internal: lets
  [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  parse and resolve the instrument once and reuse it. When `NULL`
  (default) they are computed here, so the public behaviour is
  unchanged.

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
