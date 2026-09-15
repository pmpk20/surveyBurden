# Normalise a survey definition into the `qsf_raw` shape

Accepts either the `.qsf` file shape (`SurveyEntry` + `SurveyElements`
array) or the Qualtrics API `survey-definitions` shape
(`Questions`/`Blocks`/ `SurveyFlow` objects) and returns the former.

## Usage

``` r
as_qsf_raw(def)
```

## Arguments

- def:

  A parsed survey definition list.

## Value

A `qsf_raw` object.

## Examples

``` r
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                         package = "surveyBurden")
raw_list <- jsonlite::fromJSON(qsf_path, simplifyVector = FALSE)
qsf <- as_qsf_raw(raw_list)
class(qsf)
#> [1] "qsf_raw"
```
