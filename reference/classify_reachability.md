# Partition a set of catalogue rows into always / maybe / unreachable

A question with no display logic is `always` shown. A question with
display logic is `unreachable` only when its logic is shown to be false
on this path: the questions it refers to that are not on the path (or
are themselves unreachable) are unanswered and not displayed, so their
conditions have fixed values, and if the logic is then false whatever
the on-path answers are, the question can never be shown. Otherwise it
is `maybe`. So a question whose logic is "Q9 is selected OR Q2 is
selected" stays `maybe` when only Q9 is off the path, and "Q9 is not
selected" is `maybe` (in fact always true) when Q9 is off the path.

## Usage

``` r
classify_reachability(catalogue, path_qids, display_logic = NULL)
```

## Arguments

- catalogue:

  Catalogue rows (needs `question_id`, `has_display_logic`,
  `display_logic_refs`).

- path_qids:

  Character vector of every question id on the path.

- display_logic:

  Optional named list, by question id, of each question's Qualtrics
  `DisplayLogic` tree (a question payload's `$DisplayLogic`). Without it
  the logic cannot be evaluated, so no question is classed
  `unreachable`: every question with display logic is `maybe`.
  [`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md)
  supplies it from the survey.

## Value

A list with character vectors `always`, `maybe`, `unreachable`.

## Details

Unknown conditions are treated as independent, so the rule can leave a
question as `maybe` that could be ruled out, but never marks a question
`unreachable` wrongly (within the conditions it understands;
embedded-data and other non-question conditions are always treated as
unknown).

## Examples

``` r
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                         package = "surveyBurden")
catalogue <- parse_qsf(qsf_path)
reach <- classify_reachability(catalogue, catalogue$question_id)
lengths(reach)
#>      always       maybe unreachable 
#>          20           6           0 
```
