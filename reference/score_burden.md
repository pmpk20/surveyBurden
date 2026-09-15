# Score per-question ex-ante burden

Applies the GfS points scoring rules (Heimgartner and Axhausen 2024,
[doi:10.32866/001c.121624](https://doi.org/10.32866/001c.121624) ) via
[`gfs_weights()`](https://pmpk20.github.io/surveyBurden/reference/gfs_weights.md)
to a question catalogue from
[`parse_qsf()`](https://pmpk20.github.io/surveyBurden/reference/parse_qsf.md),
adding burden points, an estimated completion time, a confidence flag
and a plain-language rationale per item. This is Layer 3 at the item
level; propagation through respondent paths is a later step.

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

## Examples

``` r
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                         package = "surveyBurden")
scored <- score_burden(parse_qsf(qsf_path))
scored[, c("question_id", "std_type", "gfs_points", "score_flag")]
#> # A tibble: 26 × 4
#>    question_id std_type      gfs_points score_flag
#>    <chr>       <chr>              <dbl> <chr>     
#>  1 QID1        descriptive           11 inferred  
#>  2 QID2        single_choice          1 auto      
#>  3 QID3        single_choice          2 auto      
#>  4 QID4        single_choice          1 inferred  
#>  5 QID5        single_choice          2 auto      
#>  6 QID6        single_choice          3 auto      
#>  7 QID7        matrix                 8 auto      
#>  8 QID8        open_text              1 inferred  
#>  9 QID9        single_choice          1 inferred  
#> 10 QID10       single_choice          2 auto      
#> # ℹ 16 more rows
```
