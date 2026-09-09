# Package index

## One-call pipeline

Run the whole analysis and get the structured report.

- [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  [`summary(`*`<burden_report>`*`)`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  : Ex-ante instrument burden report
- [`summary_line()`](https://pmpk20.github.io/surveyBurden/reference/summary_line.md)
  : One-sentence summary of a burden object

## Read a Qualtrics survey

Load a .qsf, or fetch a live survey, into one internal form.

- [`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md)
  : Read a Qualtrics survey definition

- [`fetch_qsf()`](https://pmpk20.github.io/surveyBurden/reference/fetch_qsf.md)
  : Fetch a survey definition from the Qualtrics API

- [`as_qsf_raw()`](https://pmpk20.github.io/surveyBurden/reference/as_qsf_raw.md)
  :

  Normalise a survey definition into the `qsf_raw` shape

- [`parse_qsf()`](https://pmpk20.github.io/surveyBurden/reference/parse_qsf.md)
  :

  Parse a Qualtrics `.qsf` into a standardised question catalogue

## Score questions

Classify each question and apply the GfS / Axhausen point weights.

- [`classify_question()`](https://pmpk20.github.io/surveyBurden/reference/classify_question.md)
  : Classify a single Qualtrics question payload
- [`gfs_weights()`](https://pmpk20.github.io/surveyBurden/reference/gfs_weights.md)
  : GfS / Axhausen burden weights
- [`score_burden()`](https://pmpk20.github.io/surveyBurden/reference/score_burden.md)
  : Score per-question ex-ante burden

## Resolve paths

Walk the flow and display logic to the feasible respondent paths.

- [`resolve_flow()`](https://pmpk20.github.io/surveyBurden/reference/resolve_flow.md)
  : Enumerate feasible respondent paths through the survey flow

- [`resolve_live_blocks()`](https://pmpk20.github.io/surveyBurden/reference/resolve_live_blocks.md)
  : Resolve the survey blocks a respondent can actually reach

- [`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md)
  :

  Resolve respondent paths, flow *and* display logic

- [`classify_reachability()`](https://pmpk20.github.io/surveyBurden/reference/classify_reachability.md)
  : Partition a set of catalogue rows into always / maybe / unreachable

## Path burden

Turn the resolved paths into per-path and population-weighted burden.

- [`path_burden()`](https://pmpk20.github.io/surveyBurden/reference/path_burden.md)
  : Burden per respondent path
- [`path_burden_profile()`](https://pmpk20.github.io/surveyBurden/reference/path_burden_profile.md)
  : Structural burden profile across a path's display-logic sub-states
- [`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
  : Expected burden by respondent route

## Diagnostics

Check where the calculation is exact and calibrate points to minutes.

- [`calculation_certainty()`](https://pmpk20.github.io/surveyBurden/reference/calculation_certainty.md)
  : Where the burden calculation is exact, and where it rests on
  assumptions
- [`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md)
  : Validate predicted burden against observed completion times
- [`instrument_summary()`](https://pmpk20.github.io/surveyBurden/reference/instrument_summary.md)
  : Structural summary of an instrument
