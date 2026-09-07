# Read a Qualtrics survey definition

Loads a survey definition without simplifying its JSON structure, so
nested survey elements, flow nodes and logic objects are preserved as R
lists.

## Usage

``` r
read_qsf(source)
```

## Arguments

- source:

  One of:

  - a path to a `.qsf` file;

  - a Qualtrics URL containing a survey id (`SV_...`) – fetched via
    [`fetch_qsf()`](https://pmpk20.github.io/surveyBurden/reference/fetch_qsf.md)
    (needs `QUALTRICS_API_KEY` / `QUALTRICS_BASE_URL`);

  - a bare survey id `SV_...` – also fetched via
    [`fetch_qsf()`](https://pmpk20.github.io/surveyBurden/reference/fetch_qsf.md).

## Value

A list of class `qsf_raw` with components `SurveyEntry` and
`SurveyElements`.
