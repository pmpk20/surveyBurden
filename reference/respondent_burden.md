# Expected burden by respondent route

Turns the flow/display-logic model into a per-route expected burden, so
you can say "a typical respondent faces ~X points, rising to ~Y once the
Loop & Merge sections repeat, or ~Z on the shortest complete route".

## Usage

``` r
respondent_burden(
  qsf,
  routes = NULL,
  weights = gfs_weights(),
  loop_typical = 2,
  engine = NULL
)
```

## Arguments

- qsf:

  A `qsf_raw` object or a path/URL accepted by
  [`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md).

- routes:

  Optional data frame of respondents. Recognised columns (all optional):

  `loop_<id>`

  :   Iteration count for a Loop & Merge block. `<id>` may be the
      driving question id (`loop_QID9`) or the block id (`loop_BL6`).
      Any other `loop_*` column is assigned to the survey's loop blocks
      in flow order. `0` means the respondent never entered that loop; a
      missing column falls back to `loop_typical`.

  `visit_<block_id>`

  :   `TRUE` to include a branch-gated optional block (e.g.
      `visit_BL11`). Absent or `FALSE` excludes it.

  Missing columns are treated as absent/zero.

- weights:

  A
  [`gfs_weights()`](https://pmpk20.github.io/surveyBurden/reference/gfs_weights.md)
  list.

- loop_typical:

  Loop iterations to assume for the `typical_pts` column, and for a
  route whose loop count is not supplied.

- engine:

  Optional precomputed `burden_engine()` result for this `qsf` (internal
  reuse by
  [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md);
  `NULL` builds it here, leaving the public behaviour unchanged).

## Value

If `routes` is `NULL`: a `respondent_burden` tibble, one row per
complete flow path, with `path_id`, `n_loop_blocks`, `optional_blocks`
(a list column of branch-gated block ids on that path) and `floor_pts` /
`typical_pts` / `ceiling_pts` (+ `_min` in minutes).
[`summary_line()`](https://pmpk20.github.io/surveyBurden/reference/summary_line.md)
turns it into a sentence.

If `routes` is supplied: the routes tibble with `path_id`, `matched`
(`TRUE` if the respondent's branch signature matched one of the
enumerated complete flow paths; `FALSE` falls back to the heaviest path
and warns – a route-recovery diagnostic on the flow model itself),
`pred_pts` and `pred_min` (predicted burden using each respondent's real
loop counts).
