# Classify a single Qualtrics question payload

Maps a Qualtrics `QuestionType` / `Selector` / `SubSelector` combination
to a standardised question type and extracts the structural fields the
burden scorer needs. This function reads structure only, never
semantics: a two-option multiple choice is `single_choice` whether it
means yes/no or something else.

## Usage

``` r
classify_question(payload)
```

## Arguments

- payload:

  The `Payload` list of one `SQ` survey element.

## Value

A named `list` with elements `question_id`, `std_type`,
`qualtrics_type`, `selector`, `subselector`, `n_options`, `n_rows`,
`n_cols`, `text_words`, `max_label_words` (longest response option /
matrix label, in words; `NA` if the question has no labels),
`label_text` (all response/answer labels lowercased and joined with
`" | "`, truncated; `NA` if none), `options_numeric` (`TRUE` if the
question has \>= 3 response options and every one is a number),
`question_text` (HTML-stripped, truncated to 200 characters),
`is_hidden` (`TRUE` if injected CSS/JS hides the question from the
respondent), `has_display_logic`, `display_logic_refs` (character
vector), `has_validation` and `flag`.
[`parse_qsf()`](https://pmpk20.github.io/surveyBurden/reference/parse_qsf.md)
assembles one tibble from these across every live question.

## Details

`flag` is one of `"auto"` (confident structural mapping), `"inferred"`
(mapping needs an assumption, e.g. dropdown scored by option count,
short text that might be a code field), `"manual"` (reserved for cases a
human must check) or `"unknown"` (unmapped type).
