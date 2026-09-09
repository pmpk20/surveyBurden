# Structural summary of an instrument

Structural summary of an instrument

## Usage

``` r
instrument_summary(qsf, blocks = NULL)
```

## Arguments

- qsf:

  A `qsf_raw` object from
  [`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md).

- blocks:

  Optional precomputed
  [`resolve_live_blocks()`](https://pmpk20.github.io/surveyBurden/reference/resolve_live_blocks.md)
  result for this `qsf` (internal reuse; `NULL` computes it here).

## Value

A list: `survey_name`, `n_questions`, `n_blocks`, `n_branches`,
`n_randomisers`, `n_loop_blocks`, `n_end_points`.
