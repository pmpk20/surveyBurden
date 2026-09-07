# Score per-question ex-ante burden

Applies the GfS / Axhausen scoring rules
([`gfs_weights()`](https://pmpk20.github.io/surveyBurden/reference/gfs_weights.md))
to a question catalogue from
[`parse_qsf()`](https://pmpk20.github.io/surveyBurden/reference/parse_qsf.md),
adding GfS burden points, an estimated completion time, a confidence
flag and a plain-language rationale per item. This is Layer 3 at the
item level; propagation through respondent paths is a later step.

## Usage

``` r
score_burden(catalogue, weights = gfs_weights())
```

## Arguments

- catalogue:

  A tibble from
  [`parse_qsf()`](https://pmpk20.github.io/surveyBurden/reference/parse_qsf.md).

- weights:

  A named list of weights; defaults to
  [`gfs_weights()`](https://pmpk20.github.io/surveyBurden/reference/gfs_weights.md).

## Value

`catalogue` with four columns added:

- `gfs_points`:

  Estimated GfS burden points (`NA` if the item cannot be scored – an
  unrecognised type).

- `est_seconds`:

  `gfs_points` converted at `points_per_minute`.

- `score_flag`:

  `"auto"` (the GfS mapping is deterministic from the structure),
  `"inferred"` (the structure is clear but the mapping onto a GfS
  category involved an explicit, documented judgement – the number is
  still determinate), `"manual"` (a human should check) or `"unknown"`
  (unmapped type).

- `score_basis`:

  A short human-readable statement of how the number was reached.

## Details

The published GfS Table 1 point weights are applied directly where the
required structure can be read from the QSF. Where the QSF does not
contain the quantity GfS needs – a dropdown has no Table 1 row, a slider
is not in the scheme, "lines" of text are not in a QSF – the package
applies an explicit, documented inference rule. `score_flag` and
`score_basis` say which case each item is.
