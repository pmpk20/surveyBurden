# Enumerate feasible respondent paths through the survey flow

Walks the `SurveyFlow`, forking at every `Branch` into a condition-true
and a condition-false path. Branch conditions are not evaluated: they
depend on embedded data or prior answers that are unknown ex ante, so
both outcomes are treated as feasible. The result is the *structural
path space* – every block sequence a respondent could encounter –
without any assumption about branch probabilities.

## Usage

``` r
resolve_flow(qsf, max_paths = 10000L)
```

## Arguments

- qsf:

  A `qsf_raw` object from
  [`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md).

- max_paths:

  Cap on the number of distinct paths. If the flow would produce more,
  an error is raised rather than a partial result.

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html), one row
per distinct path:

- path_id:

  Integer id.

- block_ids:

  List column: ordered `BL_...` ids the path shows.

- terminates_early:

  `TRUE` if the path hits an `EndSurvey` before the end of the flow (a
  screen-out or quota termination).

- decisions:

  List column: named logical vector, one entry per branch on a
  representative route to this path, `TRUE` = condition taken.

## Details

Within-block display logic (whether an individual question is shown) is
*not* resolved here; that is a separate step. Paths are at block
granularity.
