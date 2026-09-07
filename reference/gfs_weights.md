# GfS / Axhausen burden weights

The default scoring backend. Values are transcribed from Table 1 of
Heimgartner & Axhausen (2024), "Predicting Response Rates Once Again"
(*Findings*), which prints the GfS / ETH Zurich scheme (GfS Zurich 2006,
updated). Override any element and pass the result to
[`score_burden()`](https://pmpk20.github.io/surveyBurden/reference/score_burden.md).

## Usage

``` r
gfs_weights()
```

## Value

A named list of weights.

## Details

Table 1 items and the names used here:

|  |  |  |
|----|----|----|
| GfS item | points | weight name |
| Question or transition (up to 3 lines) | 2.0 | `descriptive_base` |
| Each additional line | 1.0 | `descriptive_per_extra_line` |
| Closed yes/no answers | 1.0 | `yes_no` |
| Simple numerical answer (e.g. year of birth) | 1.0 | `numeric_answer` |
| Rating with up to 5 possibilities | 2.0 | `rating_small` |
| Rating with more than 5 possibilities | 3.0 | `rating_large` |
| Best of ranking with cards | 4.0 | `rank_base` |
| Second and each additional best ranking | 3.0 | `rank_per_item` |
| Answer to sub-questions of up to 5 words | 1.0 | `open_short` |
| Answer to sub-questions of up to 2 lines | 2.0 | `open_medium` |
| Half-open, \< 8 possibilities (+ each additional) | 2.0 (+2.0) | `multi_small_base` / `multi_small_per_option` |
| Half-open, \>= 8 possibilities (+ each additional) | 4.0 (+3.0) | `multi_large_base` / `multi_large_per_option` |
| Answer to "please specify" | 2.0 | `please_specify` |
| First answer to an open question | 6.0 | `open_essay` |
| Each additional answer to the open question | 3.0 | `open_essay_per_extra` |
| Filter | 0.5 | `filter` |
| Branching | 0.5 | `branching` |
| Stated choice question, 2 alternatives | 2.0 | `sc_2_alt` |
| Stated choice question, 3 alternatives | 3.0 | `sc_3_alt` |
| Per SC variable, per question | 1.0 | `sc_per_variable` |

Not in Table 1 – package-derived, used only where the QSF does not
contain the quantity the scheme needs:

- `slider`:

  2.0 – GfS has no slider; a graded slider is mapped to a rating, a
  magnitude slider to a numerical answer (see
  [`score_burden()`](https://pmpk20.github.io/surveyBurden/reference/score_burden.md)).

- `matrix_cell_multi`:

  0.5 – a multiple-answer ("tick all that apply") grid has no Table 1
  rule. Each of its `rows x cols` cells is treated as one trivial closed
  yes/no decision (GfS closed yes/no is 1.0), discounted for grid
  working-memory efficiency. This is orientation-invariant – the score
  does not depend on which axis the QSF stored as rows. A documented
  inference, not GfS; the vignette describes the alternatives that were
  considered.

- `points_per_minute`:

  12 – the published GfS rule of thumb ("twelve points roughly
  correspond to a one-minute response time", Heimgartner & Axhausen
  2024). Overridable: set `w$points_per_minute` on the returned list, or
  feed a survey-specific figure from
  [`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md).

- `words_per_line`:

  12 – a **pragmatic conversion heuristic**, not an empirically
  calibrated constant. GfS scores instruction text in rendered lines; a
  QSF has words, not a rendered width. Overridable, and exposed directly
  as `burden_report(words_per_line = ...)`. The single most sensitive
  assumption for `descriptive` items.
