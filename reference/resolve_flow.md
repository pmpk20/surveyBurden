# Enumerate the structural paths through the survey flow

Walks the `SurveyFlow`, forking at every `Branch` into feasible
outcomes. When consecutive branches each test the same embedded-data
field with one comparison (`=`, `!=`, `>`, `>=`, `<`, `<=`), they are
evaluated jointly: only combinations of outcomes that some value of the
field can produce are enumerated. Equality tests against different
values become one-of-k plus a "none matches" fallback; complementary
tests such as `> 0` and `= 0` can no longer both be taken. All other
branches are still forked into a condition-true and a condition-false
path. The result is the *structural path space* – every block sequence a
respondent could encounter – without any assumption about branch
probabilities.

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

  List column: named logical vector, one entry per branch on one
  combination of branch outcomes that produces this path, `TRUE` =
  condition taken.

## Details

Field values are unrestricted: a field may hold any value or be empty,
so an outcome such as "neither `> 0` nor `= 0`" (a negative or empty
field) is kept. The enumeration is therefore an upper bound under
unrestricted field values. Where a survey's own code limits a field's
values (for example, question JavaScript that always writes a count),
some enumerated paths may be impossible in practice. `resolve_flow()`
reports branch fields it finds assigned in question JavaScript, so these
cases can be checked; it does not interpret the code, and it may not
detect every assignment.

Within-block display logic (whether an individual question is shown) is
*not* resolved here; that is a separate step. Paths are at block
granularity.

## Examples

``` r
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                         package = "surveyBurden")
flow <- resolve_flow(read_qsf(qsf_path))
flow[, c("path_id", "terminates_early")]
#> # A tibble: 4 × 2
#>   path_id terminates_early
#>     <int> <lgl>           
#> 1       1 TRUE            
#> 2       2 TRUE            
#> 3       3 FALSE           
#> 4       4 FALSE           
```
