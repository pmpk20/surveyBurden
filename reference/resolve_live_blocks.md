# Resolve the survey blocks a respondent can actually reach

Walks the `SurveyFlow` and returns the blocks it references, in flow
order, with their questions. Blocks that exist in the `.qsf` but are not
shown by the flow (typically the Qualtrics "Trash / Unused Questions"
block) are excluded.

## Usage

``` r
resolve_live_blocks(qsf)
```

## Arguments

- qsf:

  A `qsf_raw` object from
  [`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md).

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per live block:

- flow_order:

  Integer position in the flow (first occurrence).

- block_id:

  Qualtrics block id (`BL_...`).

- block_name:

  Block description.

- in_loop:

  `TRUE` if the block uses Loop & Merge.

- loop_on_qid:

  Question id the loop count depends on, else `NA`.

- loop_max:

  Maximum loop iterations, else `NA`.

- question_ids:

  List column: character vector of `QID`s in block order.
