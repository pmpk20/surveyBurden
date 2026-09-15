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

## Examples

``` r
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                         package = "surveyBurden")
blocks <- resolve_live_blocks(read_qsf(qsf_path))
blocks[, c("block_id", "block_name", "flow_order")]
#> # A tibble: 12 × 3
#>    block_id block_name      flow_order
#>    <chr>    <chr>                <int>
#>  1 BL1      Welcome                  1
#>  2 BL2      Consent                  2
#>  3 BL3      Area check               3
#>  4 BL4      About you                4
#>  5 BL5      Household                5
#>  6 BL6      Other adults             6
#>  7 BL7      Vehicles                 7
#>  8 BL8      Vehicle details          8
#>  9 BL9      Travel                   9
#> 10 BL10     Attitudes               10
#> 11 BL11     Commuting               11
#> 12 BL12     Closing                 12
```
