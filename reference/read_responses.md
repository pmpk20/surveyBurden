# Read a Qualtrics response export

Reads a response CSV as it is, so you can build per-respondent inputs,
such as a `words_per_line` vector from device metadata, for
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md).
Every column is read as text and keeps its name unchanged. A raw
Qualtrics export keeps its two header rows (question labels and
ImportId), so the result has two more rows than there are respondents.
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
accepts a vector of either length: when it removes the header rows, it
drops the matching entries too.

## Usage

``` r
read_responses(x, arg = "responses")
```

## Arguments

- x:

  Path to a CSV file, or a data frame, which is returned unchanged.

- arg:

  Argument name used in error messages.

## Value

A data frame with one row per CSV row, all columns character.

## Examples

``` r
csv <- tempfile(fileext = ".csv")
writeLines(c("ResponseId,Q1", "Response ID,Q1 text", "R_1,yes"), csv)
read_responses(csv)
#>    ResponseId      Q1
#> 1 Response ID Q1 text
#> 2         R_1     yes
```
