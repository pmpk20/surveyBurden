# Validate (and coerce) a question catalogue

Checks that a data frame has the columns
[`score_burden()`](https://pmpk20.github.io/surveyBurden/reference/score_burden.md)
needs and coerces it to a tibble.

## Usage

``` r
validate_catalogue(catalogue)
```

## Arguments

- catalogue:

  A data frame (or tibble) with at least the columns `question_id` and
  `std_type`. See **Details** for the full schema.

## Value

A tibble with all required, structural, and platform-specific columns
present (missing optional columns filled with their defaults).

## Details

A catalogue from
[`parse_qsf()`](https://pmpk20.github.io/surveyBurden/reference/parse_qsf.md)
always passes. This function is useful when you construct a catalogue by
hand for a non-Qualtrics survey: it confirms the required columns are
present, fills optional columns with safe defaults, and converts the
result to a tibble so downstream functions work unchanged.

**Required columns** (must be present):

- `question_id`:

  Character. Unique identifier for each question.

- `std_type`:

  Character. Standardised question type: one of `"single_choice"`,
  `"multi_choice"`, `"matrix"`, `"open_text"`, `"slider"`, `"ranking"`,
  `"constant_sum"`, `"descriptive"`, `"timing"`, `"meta"`, `"captcha"`.

**Structural columns** (used by the scorer; default to safe values if
missing):

- `n_options`:

  Integer. Number of response options (`NA` if unknown).

- `n_rows`:

  Integer. Number of matrix rows (`NA` for non-matrix types).

- `n_cols`:

  Integer. Number of matrix columns (`NA` for non-matrix types).

- `text_words`:

  Integer. Word count of the question stem.

- `is_dropdown`:

  Logical. `TRUE` if a single-choice dropdown.

- `is_multiline`:

  Logical. `TRUE` if a multi-line open-text field.

- `is_multi_answer`:

  Logical. `TRUE` if a checkbox-per-cell matrix.

- `is_hidden`:

  Logical. `TRUE` if hidden from the respondent.

- `options_numeric`:

  Logical. `TRUE` if all option labels are numbers.

- `label_text`:

  Character. Lowercased, joined response labels.

- `question_text`:

  Character. Plain-text question stem.

- `has_display_logic`:

  Logical. Whether the question has display logic.

- `has_validation`:

  Logical. Whether a response is forced.

- `in_loop`:

  Logical. Whether the question is inside a loop block.

- `loop_max`:

  Integer. Maximum loop iterations (`NA` if not in loop).

- `flag`:

  Character. Confidence flag (`"auto"`, `"inferred"`, `"manual"`, or
  `"unknown"`).

**Platform-specific columns** (retained for provenance; not used by the
scorer):

- `qualtrics_type`:

  Character. Original Qualtrics `QuestionType`.

- `selector`:

  Character. Qualtrics `Selector`.

- `subselector`:

  Character. Qualtrics `SubSelector`.

## Examples

``` r
# Hand-craft a tiny catalogue
cat <- data.frame(
  question_id = c("Q1", "Q2", "Q3"),
  std_type    = c("single_choice", "open_text", "matrix"),
  n_options   = c(5L, NA, NA),
  n_rows      = c(NA, NA, 4L),
  n_cols      = c(NA, NA, 5L),
  stringsAsFactors = FALSE
)
validated <- validate_catalogue(cat)
validated
#> # A tibble: 3 × 26
#>   question_id std_type      n_options n_rows n_cols text_words max_label_words
#>   <chr>       <chr>             <int>  <int>  <int>      <int>           <int>
#> 1 Q1          single_choice         5     NA     NA         NA              NA
#> 2 Q2          open_text            NA     NA     NA         NA              NA
#> 3 Q3          matrix               NA      4      5         NA              NA
#> # ℹ 19 more variables: label_text <chr>, options_numeric <lgl>,
#> #   question_text <chr>, is_hidden <lgl>, is_dropdown <lgl>,
#> #   is_multiline <lgl>, is_multi_answer <lgl>, has_display_logic <lgl>,
#> #   display_logic_refs <list>, has_validation <lgl>, in_loop <lgl>,
#> #   loop_max <int>, flag <chr>, qualtrics_type <chr>, selector <chr>,
#> #   subselector <chr>, flow_order <int>, block_id <chr>, block_name <chr>
```
