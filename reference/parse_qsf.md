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
`std_type`, `qualtrics_type`, `selector`, `subselector`, `n_options`,
`n_rows`, `n_cols`, `text_words`, `max_label_words`, `label_text`
(response/answer option labels, lowercased and joined; `NA` if none),
`options_numeric` (`TRUE` if every response option label is a number),
`question_text` (HTML-stripped, truncated to 200 characters),
`is_hidden` (`TRUE` if the question is hidden from the respondent via
injected CSS/JS), `has_display_logic`, `display_logic_refs`,
`has_validation`, `in_loop`, `loop_max`, `flag`.

## Details

This function does not resolve respondent paths or compute burden. It
reads and classifies questions.
