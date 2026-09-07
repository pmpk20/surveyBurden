# Fetch a survey definition from the Qualtrics API

Downloads a survey's definition through the Qualtrics REST API and
returns it in the same `qsf_raw` shape
[`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md)
produces from a `.qsf` file, so the rest of the pipeline
([`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
etc.) works unchanged.

## Usage

``` r
fetch_qsf(
  survey,
  api_key = Sys.getenv("QUALTRICS_API_KEY"),
  base_url = Sys.getenv("QUALTRICS_BASE_URL")
)
```

## Arguments

- survey:

  Survey id (`SV_...`) or any Qualtrics URL containing one
  (survey-builder link, distribution link, ...).

- api_key:

  Qualtrics API token. Defaults to `Sys.getenv("QUALTRICS_API_KEY")`.

- base_url:

  API base, e.g. `"https://fra1.qualtrics.com"`. Defaults to
  `Sys.getenv("QUALTRICS_BASE_URL")`, else derived from `survey` if it
  is a URL.

## Value

A `qsf_raw` object.

## Details

Needs an API token. Set `QUALTRICS_API_KEY` (and optionally
`QUALTRICS_BASE_URL`, e.g. `"https://fra1.qualtrics.com"`) in your
environment, or pass them as arguments. The token needs the "Manage
Survey" / read-definition permission.

## Examples

``` r
if (FALSE) { # \dontrun{
Sys.setenv(QUALTRICS_API_KEY = "...", QUALTRICS_BASE_URL = "https://fra1.qualtrics.com")
r <- burden_report(fetch_qsf("SV_0xIVRCCRgC1lt8a"))
} # }
```
