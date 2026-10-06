# Respondent burden from response data

The GfS+ burden each respondent experienced. For every respondent,
including those who broke off or were screened out, walks the survey
flow against their own answers and sums the GfS+ points of every item
the survey displayed to them: descriptive text, and questions left
blank, count alongside questions answered. Loop & Merge iterations are
counted separately. For a break-off, burden runs up to the block they
left in.

## Usage

``` r
respondent_burden(
  qsf,
  responses,
  scheme = gfs_scheme(),
  by = c("respondent", "block"),
  words_per_line = NULL,
  id_col = NULL,
  furthest = c("answered", "column"),
  furthest_col = NULL,
  loop_iterations = c("driver", "observed"),
  embedded = NULL
)
```

## Arguments

- qsf:

  A `qsf_raw` object, a path to a `.qsf` file, or a survey id accepted
  by
  [`fetch_qsf()`](https://pmpk20.github.io/surveyBurden/reference/fetch_qsf.md).

- responses:

  A data frame of response data, or the path to a raw Qualtrics CSV
  export. Columns must be mappable to question ids via one of these
  strategies (tried in order):

  1.  A `col_map` attribute on the data frame: a named list, one entry
      per column, each either a QID string or
      `list(qid = , iteration = )`. It overrides the automatic
      strategies for the columns it names. With a bare QID, the loop
      iteration comes from an `N_` prefix on the column name (`2_mycol`
      is iteration 2), else 0.

  2.  The ImportId row of a raw Qualtrics CSV export, which names each
      column's question whatever the column is called. Where present it
      decides alone.

  3.  Column names match question ids directly (`QID15`, `QID15_1`, or
      `2_QID15` for loop iteration 2).

  4.  Column names match `DataExportTag` values from the QSF (`Q15`,
      `travel_mode_1`), exactly or ignoring case.

  Columns Qualtrics fills automatically – display order (`_DO`),
  page-timing clicks and browser meta data – never count as answers.

  Leading label and ImportId rows from a raw Qualtrics CSV export are
  removed, with a message, when recognisable (an ImportId JSON cell, or
  a system column holding its own label such as `ResponseId` = "Response
  ID"); other rows are always kept.

  The simplest input is the raw CSV export itself (with its header
  rows).
  `qualtRics::fetch_survey(survey_id, label = FALSE, convert = FALSE, add_column_map = FALSE)`
  also works, through the column names.

- scheme:

  A
  [`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
  list. Its `words_per_line` sets the descriptive-text line conversion.

- by:

  `"respondent"` (default): one row per respondent. `"block"`: one row
  per respondent per live block.

- words_per_line:

  How many words fit on one rendered line, used only when scoring
  descriptive text. `NULL` (default) uses `scheme$words_per_line` (12).
  A single number applies to all respondents. A numeric vector with one
  value per respondent (one per row of `responses`; header rows of a raw
  export may be included and are dropped with them) lets the line length
  differ by respondent, for example by device. Mapping device metadata
  to values is left to the user.

- id_col:

  Name of the respondent-id column. Auto-detected from `"ResponseId"`,
  `"response_id"`, or the first column whose values are all unique. Its
  values must be unique and not missing; Qualtrics' `ResponseId` is.

- furthest:

  How to find the furthest block a respondent reached: `"answered"`
  (default) uses the last block with an answer; `"column"` reads
  `furthest_col`.

- furthest_col:

  Name of a column holding, per respondent, the last block reached: a
  block id, a block name, a question id (its block is used) or a
  whole-number block ordinal (`flow_order` from
  [`resolve_live_blocks()`](https://pmpk20.github.io/surveyBurden/reference/resolve_live_blocks.md)),
  matched in that order, so a block named `"2"` is that block. Blank or
  unrecognised values fall back to `"answered"`.

- loop_iterations:

  `"driver"` (default) or `"observed"`; see Loops.

- embedded:

  Optional named character vector mapping embedded-data field names to
  response columns, e.g. `c(TotalVehicles = "total_vehicles")`.
  Overrides the automatic matching for the fields it names.

## Value

With `by = "respondent"`, a
[tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per respondent, in the order of `responses`:

- `response_id`:

  Respondent identifier.

- `finished`:

  Logical, from the `Finished` column (`NA` if absent).

- `outcome`:

  `"complete"`, `"breakoff"` or `"screen_out"` (the flow ended the
  survey early).

- `points`:

  Respondent burden: GfS+ points of every item displayed (each loop
  iteration counted).

- `minutes`:

  `points / points_per_minute`.

- `items`, `response_items`:

  Visible items displayed, and those of them that take a response (not
  descriptive text).

- `pages`:

  Pages displayed.

- `furthest_order`:

  Flow order of the furthest block reached (`NA` for respondents who
  reached the end).

- `n_unresolved_items`, `n_unresolved_branches`:

  Display and branch decisions the logic could not settle, which fell
  back to whether the respondent answered.

- `unresolved_loops`:

  `TRUE` if a loop's iterations could not be recovered.

- `n_routing_conflicts`:

  Blocks with answers that the evaluated flow did not route the
  respondent into (the answers are trusted).

With `by = "block"`, a tibble with one row per respondent per live
block, in flow order:

- `response_id`:

  Respondent identifier.

- `block_id`, `block_name`, `flow_order`:

  The block.

- `outcome`:

  As above.

- `routed_in`:

  `TRUE` if the flow routed the respondent into the block, `FALSE` if it
  did not, `NA` for blocks after their exit.

- `displayed`:

  `TRUE` if the block showed at least one visible question (Qualtrics
  skips a block whose questions are all hidden).

- `iterations`:

  Loop & Merge iterations displayed; `NA` for other blocks.

- `points`:

  GfS+ points of the items displayed in the block.

- `items`, `response_items`, `pages`:

  As above, for the block.

- `hidden_items`:

  Items the respondent passed that are never visible (hidden by injected
  CSS/JS, page timing, metadata). They score 0 points and are not in
  `items`; reported for completeness.

- `design_points`:

  The block's design score (its questions scored once), as in
  `burden_report()$blocks`.

- `exit_block`:

  `TRUE` on the block the respondent left the survey in (break-offs and
  screen-outs only).

- `unresolved_items`:

  Display decisions in this block that the logic could not settle.

Block counts are `NA` where `routed_in` is `NA`, and 0 where it is
`FALSE`. The attribute `respondents` holds the respondent-level
diagnostics.

## Details

`by = "respondent"` (default) returns one row per respondent.
`by = "block"` returns one row per respondent per block, the input for a
break-off (discrete-time hazard) model; see
[`exposure_person_period()`](https://pmpk20.github.io/surveyBurden/reference/exposure_person_period.md).

**What is evaluated.** Branch logic in the survey flow and display logic
on questions are evaluated per respondent, in flow order, so that
`Displayed()` literals see earlier decisions. Supported literals:
question `Selected` / `NotSelected` (single choice, multiple choice and
matrix cells, via the QSF `RecodeValues`), `Displayed` / `NotDisplayed`,
`Empty` / `NotEmpty` and numeric or text comparisons on a question's
entry value, embedded-data comparisons, and the Loop & Merge "current
loop" test. Embedded fields are read from a response column of the same
name (matched exactly, then ignoring case, then ignoring case and
punctuation), or from a fixed value set in the flow. A fixed value set
in the flow holds from that point on, so a field set more than once is
read as it stood at each branch. A cell holding several choice codes
joined by commas (`"1,4"`) is split only when every piece is one of the
question's choice codes, so a choice label containing a comma is never
split.

**What cannot be evaluated** (an unsupported literal such as a quota
test, an embedded field with no column and no fixed value – typically
one set by question JavaScript – or a trigger question with no response
columns) is never silently treated as true or false. Three-valued logic
is used, so an unknown literal matters only when it decides the outcome.
When it does: an item counts as displayed if the respondent answered it,
and is counted in `unresolved_items`; a branch counts as taken if the
respondent answered a question in a block inside it (or, for a branch
that ends the survey, if they finished without answering anything
later), and is counted in the `respondents` attribute's
`n_unresolved_branches`.

**Exit.** A respondent's exit is the furthest block they reached: by
default the last block in which they answered a question
(`furthest = "answered"`). Someone who leaves on a newly displayed page
without answering is therefore attributed to the previous block; supply
a last-seen block or question in `furthest_col` to avoid this.
Respondents marked finished reached every block the flow routed them
into. Blocks after the exit have `routed_in = NA`: the flow beyond that
point depends on answers that were never given. Qualtrics records a
screened-out response as finished, so a respondent marked unfinished is
a break-off, never a screen-out.

**Loops.** The iterations a Loop & Merge block ran are taken from the
question driving the loop (the numeric response, or the selected
choices) when that answer is available, else from the iterations with
any answer (`loop_iterations = "observed"` forces the latter).
Iterations with answers are always counted. In the exit block of a
break-off, only iterations up to the last one answered are counted.
Export columns number a choice-driven loop by the choice's position, so
iteration `j` is the driving question's `j`-th choice. A randomised loop
is not shown in export order: at a break-off only the iterations
answered count, and where the driver cannot settle the iterations, or
the loop presents only a subset of them, they come from the answers
alone. Those respondents are flagged in `unresolved_loops`, as are
respondents in loops whose size the QSF does not give.

Answers that contradict the evaluated flow (answers in a block the flow
did not route the respondent into) are trusted: the block counts as
routed in, and the respondent's `n_routing_conflicts` is incremented.

## See also

[`exposure_person_period()`](https://pmpk20.github.io/surveyBurden/reference/exposure_person_period.md)
to turn the `by = "block"` result into hazard data;
[`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md)
to compare respondent burden with completion times.

## Examples

``` r
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                         package = "surveyBurden")
responses <- data.frame(
  ResponseId = c("R_1", "R_2", "R_3"),
  Finished   = c(1, 0, 1),
  QID2  = c("1", "1", "2"),   # consent: R_3 declines and is screened out
  QID3  = c("1", "1", NA),
  QID4  = c("2", "3", NA),
  QID6  = c("1", "4", NA),    # R_1 employed: routed into Commuting
  QID9  = c("2", NA, NA),     # two adults: the loop runs twice
  QID10 = c("1", NA, NA),
  `1_QID11` = c("2", NA, NA),
  QID19_1 = c("3", NA, NA),
  QID22 = c("3", NA, NA),
  QID26 = c("1", NA, NA),
  check.names = FALSE
)
respondent_burden(qsf_path, responses)
#> ℹ Logic not settled by the data for 1 respondent: 2 question decisions and 0
#>   branch decisions fell back to whether they answered.
#> ℹ See `attr(x, "respondents")`.
#> # A tibble: 3 × 13
#>   response_id finished outcome    points minutes items response_items pages
#>   <chr>       <lgl>    <chr>       <dbl>   <dbl> <int>          <int> <int>
#> 1 R_1         TRUE     complete      109    9.08    24             23    12
#> 2 R_2         FALSE    breakoff       29    2.42     8              7     4
#> 3 R_3         TRUE     screen_out     12    1        2              1     2
#> # ℹ 5 more variables: furthest_order <dbl>, n_unresolved_items <int>,
#> #   n_unresolved_branches <int>, unresolved_loops <lgl>,
#> #   n_routing_conflicts <int>
rb <- respondent_burden(qsf_path, responses, by = "block")
#> ℹ Logic not settled by the data for 1 respondent: 2 question decisions and 0
#>   branch decisions fell back to whether they answered.
#> ℹ See `attr(x, "respondents")`.
rb[rb$response_id == "R_1", c("block_name", "routed_in", "points")]
#> # A tibble: 12 × 3
#>    block_name      routed_in points
#>    <chr>           <lgl>      <dbl>
#>  1 Welcome         TRUE          11
#>  2 Consent         TRUE           1
#>  3 Area check      TRUE           2
#>  4 About you       TRUE          15
#>  5 Household       TRUE           3
#>  6 Other adults    TRUE          10
#>  7 Vehicles        TRUE          12
#>  8 Vehicle details TRUE           0
#>  9 Travel          TRUE          26
#> 10 Attitudes       TRUE          18
#> 11 Commuting       TRUE           4
#> 12 Closing         TRUE           7
```
