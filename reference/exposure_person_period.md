# Person-period (hazard) data from realised exposure

Turns
[`realised_exposure()`](https://pmpk20.github.io/surveyBurden/reference/realised_exposure.md)
output into one row per respondent per block at risk, ready for a
discrete-time hazard model of break-off. A respondent is at risk in a
block they were routed into and that displayed at least one question;
the block they left in is always kept.

## Usage

``` r
exposure_person_period(x)
```

## Arguments

- x:

  Output of
  [`realised_exposure()`](https://pmpk20.github.io/surveyBurden/reference/realised_exposure.md).

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with the
columns of `x` for the rows at risk, plus `period` (1, 2, ... within
respondent), `event` (1 on the exit row of a break-off, else 0;
screen-outs and completes are censored), `points_before` (GfS+ points
shown in earlier blocks) and `block_points` (the block's design score,
`design_points`).

## Examples

``` r
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                         package = "surveyBurden")
responses <- data.frame(
  ResponseId = c("R_1", "R_2"), Finished = c(1, 0),
  QID2 = c("1", "1"), QID3 = c("1", "1"), QID4 = c("2", "3"),
  QID6 = c("1", "4"), QID9 = c("1", NA), QID26 = c("1", NA)
)
pp <- exposure_person_period(realised_exposure(qsf_path, responses))
#> ℹ Logic not settled by the data for 1 respondent: 3 question decisions and 0
#>   branch decisions fell back to whether they answered.
#> ℹ See `attr(x, "respondents")`.
pp[, c("response_id", "block_name", "period", "event", "points_before")]
#> # A tibble: 15 × 5
#>    response_id block_name   period event points_before
#>    <chr>       <chr>         <int> <int>         <dbl>
#>  1 R_1         Welcome           1     0             0
#>  2 R_1         Consent           2     0            11
#>  3 R_1         Area check        3     0            12
#>  4 R_1         About you         4     0            14
#>  5 R_1         Household         5     0            29
#>  6 R_1         Other adults      6     0            32
#>  7 R_1         Vehicles          7     0            36
#>  8 R_1         Travel            8     0            48
#>  9 R_1         Attitudes         9     0            74
#> 10 R_1         Commuting        10     0            92
#> 11 R_1         Closing          11     0            96
#> 12 R_2         Welcome           1     0             0
#> 13 R_2         Consent           2     0            11
#> 14 R_2         Area check        3     0            12
#> 15 R_2         About you         4     1            14
```
