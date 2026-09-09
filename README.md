# surveyBurden

<!-- badges: start -->
[![R-CMD-check](https://github.com/pmpk20/surveyBurden/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/pmpk20/surveyBurden/actions/workflows/R-CMD-check.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![ORCID](https://img.shields.io/badge/ORCID-0000--0001--8550--466X-A6CE39?logo=orcid)](https://orcid.org/0000-0001-8550-466X)
[![Codecov test coverage](https://codecov.io/gh/pmpk20/surveyBurden/graph/badge.svg)](https://app.codecov.io/gh/pmpk20/surveyBurden)
<!-- badges: end -->

surveyBurden reads a Qualtrics survey and estimates how much response effort the
programmed instrument requires, from the survey design alone, before it is
fielded.

Qualtrics is a commercial platform for building and running online surveys,
widely used in academic and commercial research. surveyBurden is an independent
project: its authors and contributors have no affiliation with Qualtrics, and
Qualtrics provides no support for this package.

## Installation

surveyBurden is not on CRAN. Install the development version from GitHub:

```r
# install.packages("pak")
pak::pak("pmpk20/surveyBurden")

# or, with remotes:
# install.packages("remotes")
remotes::install_github("pmpk20/surveyBurden")
```

To work from a local clone, use `pkgload::load_all("path/to/surveyBurden")` for
one-off use, or `R CMD INSTALL path/to/surveyBurden` to install it.

Dependencies: `jsonlite`, `cli` and `tibble`, plus `httr2` only if you fetch
from the Qualtrics API.

## Quick start

```r
library(surveyBurden)

qsf <- system.file("extdata", "demo_travel_survey.qsf", package = "surveyBurden")
report <- burden_report(qsf)
report
```

```
#> ── Survey Burden Report: Neighbourhood Travel Survey (demo) ────────────────────
#>
#> ── Instrument ──
#>
#> Questions (live)     26
#> Blocks               12
#> Branch points         3
#> Randomisers           0
#> Loop & Merge blocks   2
#> Early-exit points     2
#>
#> ── Paths ──
#>
#> Structural paths: 4 (2 complete, 2 screen-out)
#> Display-logic combinations checked: 3-4 per complete path
#>
#> ── Burden (12 GfS points ~ 1 minute; index = points / 1500) ──
#>
#> Statistic        Points  ~Min  Index
#> ------------------------------------
#> Minimum             106     9   0.07
#> 25th percentile     117    10   0.08
#> Median              123    10   0.08
#> 75th percentile     129    11   0.09
#> Maximum             143    12   0.10
#> Benchmark: median 399 points across 79 GfS-scored survey waves (Heimgartner &
#> Axhausen 2024).
#>
#> ── Burden by block (survey order; share of all-question points) ──
#>
#> Welcome                   10%  ###
#> Consent                    1%  #
#> Area check                 2%  #
#> About you                 13%  ####
#> Household                  3%  #
#> Other adults               4%  #
#> Vehicles                  12%  ###
#> Vehicle details            5%  ##
#> Travel                    23%  #######
#> Attitudes                 16%  #####
#> Commuting                  5%  ##
#> Closing                    6%  ##
#>
#> ── Highest-burden questions ──
#>
#> QID21      18 pts  6x7      How much do you agree with each statement?
#> QID19      14 pts  7x4      In the past month, how often did you use each of these?
#> QID14      12 pts  6 opt    Which of these does your household own or have use of? ...
#> QID20      12 pts  6x4      And for each of these reasons for travelling, how often...
#> QID1       11 pts  0 opt    Welcome, and thank you for taking part in the Neighbour...
#> QID7        8 pts  4x3      For each area, do you have a condition that makes trave...
#>
#> ── Readability diagnostics (reading load; not part of the GfS score) ──
#>
#> Long stems (> 40 words)          0
#> Long matrix labels (> 10 words)  0
#> Long grids (> 6 rows)            1
#>
#> ── Calculation certainty ──
#>
#> Paths: 0/2 resolve exactly; 2 carry an unresolved display-logic condition.
#> Display logic: 6/6 conditional questions enumerated exactly, 0 approximated.
#> Loops: 2 with a known cap, 0 unknown.  Item scores: 19 auto / 7 inferred / 0
#> manual.
#>
#> ── QC warnings (3) ──
#>
#> ! 1 matrix/grid question has more than 6 rows. Long grids invite satisficing
#>   (respondents picking the same answer down the column instead of reading each
#>   row): QID19
#> ! 2 of 4 structural paths are screen-outs (the survey ends early there) rather
#>   than complete responses.
#> ! The point range above comes from checking every combination of optional
#>   questions this survey's skip logic could show. Each combination is counted
#>   once; we have no data on how likely each one is for a given respondent, so
#>   this is a structural range, not a probability -- it does NOT mean "there's a
#>   50% chance a respondent sees the median burden".
```

`summary(report)` prints a one-line headline:

```r
summary(report)
#> ── Neighbourhood Travel Survey (demo) ──────────────────────────────────────────
#> 26 questions, 12 blocks, 4 structural paths (2 complete).
#> Burden: 106 / 123 / 143 points (min / median / max; ~9 / 10 / 12 min).
#> Benchmark: median 399 points across 79 GfS-scored waves.
```

## Working with the report object

`report` is a structured object, not printed text. Pull out each part:

```r
report$instrument  # one-row tibble of the survey's structural counts
report$burden      # min / p25 / median / p75 / max, in points, minutes and index
report$items       # one row per question, with its GfS score and the rule used
report$paths       # one row per structural path, with its burden floor and ceiling
report$blocks      # burden totalled by block, in survey order
```

- `report$instrument` — questions, blocks, branch points, Loop & Merge blocks
  and structural paths.
- `report$burden` — the headline spread of **path burden** across the survey.
- `report$items` — every live question, its standard type, its point score, and
  a `score_flag` saying how the score was reached.
- `report$paths` — each structural path, whether it completes or screens out,
  and the burden range along it.
- `report$blocks` — question burden by block, with each block's share.

Scalar settings (the points-per-minute rate, the rare-value threshold) are
stored as attributes: `attr(report, "points_per_minute")`,
`attr(report, "rare_threshold")`.

## Fetching from Qualtrics

Set your credentials as environment variables, then pass a survey URL or ID to
`burden_report()`:

```r
Sys.setenv(
  QUALTRICS_API_KEY  = "your-api-key",
  QUALTRICS_BASE_URL = "https://yourdatacenter.qualtrics.com"
)
burden_report("https://yourorg.qualtrics.com/survey-builder/SV_xxxxxxxxxxxxxxxx/edit")
```

Only the survey ID (`SV_...`) is needed, so a survey-builder link, a
distribution link (`.../jfe/form/SV_...`), or the bare `SV_` id all work.
`burden_report()` fetches the survey **definition**, not its responses.

`QUALTRICS_BASE_URL` is the API datacenter host, which can differ from your
survey-builder host. Check Account Settings, then Qualtrics IDs. Credentials are
read from the environment and never appear in code.

You can only score a survey you can access. `burden_report()` reads the survey
**definition** through the `survey-definitions` API, which requires a token with
the "Manage Survey" permission on that survey — normally a survey in your own
Qualtrics account. A public participation link
(`.../jfe/form/SV_...`) only lets a respondent *take* the survey; it does not
expose the definition. To score someone else's survey you need either their
`.qsf` export or an API token for the account that owns it.

## What surveyBurden does

It takes a Qualtrics `.qsf` export (a JSON file), or a live survey through the
API, and scores every question with the published GfS / Axhausen burden scheme
(Heimgartner & Axhausen 2024, Table 1). It then follows the survey's flow and
display logic, works out which questions can appear together, and reports how
burden varies across the possible respondent paths. The score for one question
is its **question burden**; the total along one route through the survey is a
**path burden**.

A survey often contains many questions that not every respondent sees. Skip
logic, branches and display rules send different people down different routes. A
burden figure worked out by hand, or a single expected duration, describes one
route that few respondents take. surveyBurden reconstructs the programmed routes
and reports the resulting profile: the shortest route, the longest route, and
the spread between them.

The package describes the instrument, not the respondent. It does not claim that
burden causes dropout, satisficing or slower responses — those are empirical
questions that sit outside what this package does.

### How it works

1. **Read the Qualtrics survey.** Load the `.qsf`, or fetch it through the API,
   and normalise to one internal form.
2. **Identify and score the questions.** Classify each Qualtrics widget as a
   standard question type, then assign its GfS point score.
3. **Reconstruct which questions can appear together.** Walk the survey flow and
   the display logic to find the feasible respondent paths.
4. **Summarise burden across those paths.** Pool the per-path results into the
   headline spread and the block breakdown.

### GfS scoring

surveyBurden implements the published GfS / Axhausen scheme; it does not invent
a new burden scale. The point weights are transcribed from the published table
into `gfs_weights()`.

Some Qualtrics constructs do not map exactly onto the original scheme. A
dropdown has no row in the table; a slider is not in the scheme; the table
counts rendered lines of text, which a `.qsf` does not store. Where the mapping
is uncertain, the package records that through a `score_flag` on the question
(`auto`, `inferred`, `manual` or `unknown`) and a `score_basis` string naming
the rule applied. It does not pretend the classification is exact.

| response action | GfS points |
|---|---|
| yes / no question | 1 |
| rating scale, up to 5 options | 2 |
| rating scale, more than 5 options | 3 |
| first answer to an open question | 6 |
| two-alternative stated-choice task | 2 |

The full table is in Heimgartner & Axhausen (2024),
<https://findingspress.org/article/125481-predicting-response-rates-once-again>.
It is not reproduced here.

### Path-specific burden

Suppose a survey asks whether the respondent owns a car; only car owners then
see five follow-up questions about their vehicles. A single burden total mixes
the two groups and describes neither. surveyBurden represents both routes. It
handles flow branches, question-level display logic, optional (skippable)
questions, Loop & Merge blocks that repeat once per selected item, complete
paths, and screen-out paths where the survey ends early.

The default result is a **structural burden profile**: each feasible path and
each display-logic sub-state is counted once. It is not a probability
distribution over respondents — the "median" is the middle value across the
feasible combinations, not the burden half of respondents exceed.

If you have real respondent route data, supply it and the report adds the
**population-weighted respondent burden**:

```r
# routes: one row per respondent. Recognised columns are loop_<id> (the
# iteration count for a Loop & Merge block, keyed by its driving question id or
# block id) and visit_<block_id> (TRUE to include a branch-gated block).
routes <- data.frame(
  loop_BL6 = c(0, 2, 1, 3, 2),   # "Other adults" loop
  loop_BL8 = c(1, 1, 0, 2, 1)    # "Vehicle details" loop
)
burden_report(qsf, routes = routes)
```

### Points and minutes

The GfS framework uses roughly 12 points per minute as a rule of thumb, from the
original framework. It is a rough scale, not a web-specific calibration, and not
a prediction of completion time. Override it by setting `points_per_minute` on a
weights object:

```r
w <- gfs_weights()
w$points_per_minute <- 15
burden_report(qsf, weights = w)
```

For a figure specific to your survey, run `validate_times()` on your own
completion-time data and use the rate it returns.

## Pipeline and API reference

`burden_report()` runs the whole pipeline. The lower-level functions expose each
step.

| function | output |
|---|---|
| `read_qsf(source)` | internal survey object from a `.qsf` path, `SV_` id or URL |
| `fetch_qsf(survey, api_key, base_url)` | the same object, fetched through the API |
| `parse_qsf(x)` | question catalogue, one row per live question |
| `classify_question(payload)` | standard question type for one question |
| `gfs_weights()` | the GfS Table 1 point weights and the time conversion |
| `score_burden(catalogue, weights)` | catalogue plus `gfs_points`, `score_flag`, `score_basis` |
| `resolve_flow(qsf, max_paths)` | the distinct block sequences (structural paths) |
| `resolve_paths(qsf, max_paths)` | per path: questions always shown, may be shown, never shown |
| `classify_reachability(catalogue, path_qids)` | reachability label for each question on a path |
| `path_burden(qsf, weights, max_paths)` | burden floor and ceiling per path |
| `path_burden_profile(qsf, weights, max_paths)` | enumerated feasible burden values per path |
| `respondent_burden(qsf, routes, weights, loop_typical)` | population-weighted burden from observed routes |
| `summary_line(x, ...)` | a one-sentence burden summary |
| `calculation_certainty(qsf, weights, max_paths)` | which parts of the calculation are exact and which are approximated |
| `burden_report(x, weights, profile, routes, rare_threshold, ...)` | the structured report object |
| `validate_times(qsf, observed, weights, trim)` | a points-per-minute rate fitted to your completion-time data |

Every function has a help page: `?burden_report`, `?score_burden`, and so on.
The vignette walks through the whole workflow: `vignette("surveyBurden")`.

## Limitations

- The Qualtrics-to-GfS mapping is sometimes inferential; the package applies a
  documented rule and flags the question.
- The GfS scheme predates modern web survey interfaces.
- Rendered text length cannot be recovered exactly from a `.qsf`, so
  `words_per_line` is a configurable proxy.
- Display-logic reconstruction depends on what the `.qsf` encodes; unusual or
  externally controlled logic may need manual interpretation.
- The structural burden profile is not a respondent probability distribution.
- The points-to-minutes conversion is a rule of thumb, not a completion-time
  forecast.

The vignette covers each of these in full.

## Contributing

Bug reports, questions and pull requests are welcome — see
[`.github/CONTRIBUTING.md`](.github/CONTRIBUTING.md). Participants are expected
to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Citation

`citation("surveyBurden")`, or see [`CITATION.cff`](CITATION.cff).

## Licence

MIT. Peter King, Institute for Transport Studies, University of Leeds.
