# Suggest questions that may be stated-choice tasks

A QSF does not mark a question as a stated-choice (choice-experiment)
task, and the attributes are often laid out in an HTML table or an
image. This function looks for likely candidates so you can check them
and declare them through the `choice_tasks` argument of
[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
and the other burden functions. It never scores anything itself.

## Usage

``` r
suggest_choice_tasks(qsf)
```

## Arguments

- qsf:

  A `qsf_raw` object or a path to a `.qsf` file.

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html), one row
per suggested question, in survey order: `question_id`, `block_id`,
`block_name`, `n_alternatives`, `n_attributes`, `n_in_block` (how many
suggested questions share the block) and `evidence`.

## Details

A visible single-choice question is suggested when any of these holds:

- its stem contains an HTML `<table>`;

- the nearest text item before it in the same block contains a `<table>`
  (the scenario shown above the choice);

- its stem contains an image (`<img>`) and at least one other such
  question is in the same block (choice tasks repeat; a lone image
  question is left out).

`n_alternatives` is the option count (an opt-out such as "neither"
counts as an alternative), or `NA` above five options, where the answer
scale is more likely a graded preference between fewer alternatives.
`n_attributes` is a guess: the table rows holding data cells (`<td>`),
so a header row of `<th>` cells only is not counted; `NA` when the
attributes are in an image. Check both counts against the questionnaire
and fill in any `NA` before passing the result to `choice_tasks` (which
rejects `NA`).

## Examples

``` r
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                         package = "surveyBurden")
suggest_choice_tasks(qsf_path)
#> # A tibble: 0 × 7
#> # ℹ 7 variables: question_id <chr>, block_id <chr>, block_name <chr>,
#> #   n_alternatives <lgl>, n_attributes <int>, n_in_block <int>, evidence <chr>
```
