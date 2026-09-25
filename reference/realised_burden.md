# Realised response burden from observed responses

Scores the questions each respondent actually answered, using the GfS+
scheme and the survey's structure from the QSF. Unlike
[`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md),
which predicts burden from structural paths, this function measures it
from data: every respondent gets a unique score reflecting their actual
route through the survey.

## Usage

``` r
realised_burden(
  qsf,
  responses,
  scheme = gfs_scheme(),
  words_per_line = NULL,
  id_col = NULL
)
```

## Arguments

- qsf:

  A `qsf_raw` object, a path to a `.qsf` file, or a survey id accepted
  by
  [`fetch_qsf()`](https://pmpk20.github.io/surveyBurden/reference/fetch_qsf.md).

- responses:

  A data frame of response data. Columns must be mappable to question
  ids via one of these strategies (tried in order):

  1.  Column names match question ids directly (`QID15`, `QID15_1`).

  2.  Column names match `DataExportTag` values from the QSF (`Q15`,
      `travel_mode_1`).

  3.  A `col_map` attribute on the data frame maps column names to QIDs
      (set by a future `read_responses()` helper from the Qualtrics CSV
      ImportId row).

  The recommended way to obtain this data frame is
  `qualtRics::fetch_survey(survey_id, label = FALSE, convert = FALSE, add_column_map = FALSE)`.

- scheme:

  A
  [`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
  list.

- words_per_line:

  How many words fit on one rendered line, used only when scoring
  descriptive-text questions. `NULL` (default) uses
  `scheme$words_per_line` (12). A single number applies to all
  respondents. A numeric vector of length `nrow(responses)` gives
  per-respondent values, allowing the user to reflect device differences
  (e.g., phone vs desktop). The user is responsible for mapping device
  metadata to appropriate values; the package does not assume any
  device-to-value mapping.

- id_col:

  Name of the respondent-id column. Auto-detected from `"ResponseId"`,
  `"response_id"`, or the first column whose values are all unique. Pass
  explicitly to override.

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per respondent:

- `response_id`:

  Respondent identifier (from `id_col`).

- `finished`:

  Logical: did the respondent reach the end?

- `furthest_block`:

  Integer ordinal of the last block in which the respondent answered at
  least one question.

- `n_questions_answered`:

  Count of distinct questions with at least one non-blank response
  column.

- `realised_points`:

  Sum of GfS points for answered questions; loop questions scored once
  per answered iteration.

- `realised_minutes`:

  `realised_points / points_per_minute`.

- `predicted_points`:

  Structural-path prediction for comparison (from
  [`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
  logic, using inferred loop counts and visit flags).

- `predicted_minutes`:

  `predicted_points / points_per_minute`.

- `words_per_line`:

  The words-per-line value used for each respondent's descriptive-text
  scoring.

- `n_unmapped_cols`:

  Number of response columns that could not be mapped to any question in
  the QSF.

## Recommended Qualtrics export

Via the API (cleanest):

    responses <- qualtRics::fetch_survey(
      surveyID   = "SV_...",
      label      = FALSE,    # numeric recode values, not choice text
      convert    = FALSE,    # keep raw strings, don't coerce
      force_request = TRUE   # bypass cache
    )
    qsf <- fetch_qsf("SV_...")
    rb  <- realised_burden(qsf, responses)

Via CSV download: Data & Analysis \> Export & Import \> Export Data \>
CSV. Tick "Use numeric values". Read with
`read.csv("file.csv", check.names = FALSE)` and pass directly. The
column names will be the question export tags; the function maps them
via the QSF.

## Examples

``` r
# \donttest{
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                         package = "surveyBurden")
# Simulate response data with QID-based column names
responses <- data.frame(
  ResponseId = paste0("R_", 1:5),
  Finished   = c(1, 1, 1, 0, 0),
  QID1       = rep(NA, 5),          # descriptive text, no response
  QID2       = c("1", "2", "1", "1", NA),
  QID3       = c("2", "1", "3", NA, NA),
  stringsAsFactors = FALSE
)
rb <- realised_burden(qsf_path, responses)
rb[, c("response_id", "finished", "realised_points", "predicted_points")]
#> # A tibble: 5 × 4
#>   response_id finished realised_points predicted_points
#>   <chr>       <lgl>              <dbl>            <dbl>
#> 1 R_1         TRUE                   3               95
#> 2 R_2         TRUE                   3               95
#> 3 R_3         TRUE                   3               95
#> 4 R_4         FALSE                  1               95
#> 5 R_5         FALSE                  0               95
# }
```
