# Parse a Qualtrics `.qsf` into a standardised question catalogue

The Layer 1 entry point. Reads the file (or an already-loaded object),
resolves the flow-reachable blocks, and classifies every live question
into a standardised type with the structural fields the burden scorer
needs.

## Usage

``` r
parse_qsf(x)
```

## Arguments

- x:

  A path to a `.qsf` file, or a `qsf_raw` object from
  [`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md).

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html), one row
per live question, ordered by flow position then within-block position.
Columns: `question_id`, `flow_order`, `block_id`, `block_name`,
`std_type`, `qualtrics_type`, `selector`, `subselector`, `is_dropdown`
(`TRUE` if the question is a single-choice dropdown), `is_multiline`
(`TRUE` if open text with a multi-line entry area), `is_multi_answer`
(`TRUE` if a matrix where each cell is a checkbox), `n_options`,
`n_rows`, `n_cols`, `text_words`, `max_label_words`, `label_text`
(response/answer option labels, lowercased and joined; `NA` if none),
`options_numeric` (`TRUE` if every response option label is a number),
`question_text` (HTML-stripped, truncated to 200 characters),
`is_hidden` (`TRUE` if the question is hidden from the respondent via
injected CSS/JS), `has_display_logic`, `display_logic_refs`,
`has_validation`, `in_loop`, `loop_max`, `flag`.

## Details

This function does not resolve survey paths or compute burden. It reads
and classifies questions.

## Examples

``` r
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                         package = "surveyBurden")
catalogue <- parse_qsf(qsf_path)
catalogue[, c("question_id", "std_type", "n_options")]
#> # A tibble: 26 × 3
#>    question_id std_type      n_options
#>    <chr>       <chr>             <int>
#>  1 QID1        descriptive           0
#>  2 QID2        single_choice         2
#>  3 QID3        single_choice         3
#>  4 QID4        single_choice        75
#>  5 QID5        single_choice         4
#>  6 QID6        single_choice         6
#>  7 QID7        matrix               NA
#>  8 QID8        open_text             0
#>  9 QID9        single_choice         8
#> 10 QID10       single_choice         4
#> # ℹ 16 more rows
```
