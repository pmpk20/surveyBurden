# surveyBurden -- canonical handoff

This is the current-state briefing for the package. It replaces the earlier
working notes. It is kept out of the built package (`.Rbuildignore`), but it is
committed and public.

## What the package is

surveyBurden is an R package. It takes a Qualtrics `.qsf` export, or a live
survey through the Qualtrics API, and scores every question with the published
GfS / Axhausen burden scheme (Heimgartner & Axhausen 2024, Table 1). It then
follows the survey's flow and display logic, works out which questions can appear
together, and reports how burden varies across the possible respondent paths. The
score for one question is its question burden. The total along one route through
the survey is a path burden. The package describes the programmed instrument. It
does not model respondent behaviour.

## Architecture

The package is a simple layered pipeline. Each layer has one job and a small
number of exported functions. This design was kept deliberately: the steps are
easy to test in isolation, and a user can call any layer directly.

| step | what it does | exported functions |
|---|---|---|
| read | load a `.qsf` path, `SV_` id or URL, or fetch through the API, and normalise to one internal object | `read_qsf`, `fetch_qsf` |
| parse | build a question catalogue, one row per live question | `parse_qsf`, `classify_question` |
| classify and score | assign a standard question type and its GfS point score, with a flag for how the score was reached | `gfs_weights`, `score_burden` |
| resolve flow | walk the survey flow, forking at each branch and screen-out without evaluating conditions, to get the structural paths | `resolve_flow` |
| resolve paths | partition each path's questions into always shown, may be shown, never shown | `resolve_paths`, `classify_reachability` |
| enumerate profile | enumerate the feasible display-logic states on each path and their burden values | `path_burden`, `path_burden_profile` |
| aggregate and report | pool the per-path results, weight by observed routes if supplied, and assemble the report | `respondent_burden`, `summary_line`, `calculation_certainty`, `burden_report` |

`validate_times()` is a separate helper. It fits a points-per-minute rate to a
user's own completion-time data. It is not part of the burden calculation.

`burden_report()` runs the whole pipeline in one call.

## The structured `burden_report` object

`burden_report()` returns a structured object, not printed text. Its components
are:

- `$instrument` -- one-row tibble of structural counts.
- `$burden` -- the headline spread of path burden: min, p25, median, p75, max,
  in points, minutes and index.
- `$blocks` -- question burden totalled by block, in survey order, with each
  block's share.
- `$items` -- one row per live question, with its standard type, `gfs_points`,
  `score_flag` and `score_basis`.
- `$paths` -- one row per structural path, its status (complete or screen-out),
  and its burden floor and ceiling.
- `$readability` -- long stems, long matrix labels, long grids. Reading-load
  signals, reported separately, never folded into the GfS score.
- `$certainty` -- the split between parts of the calculation that are exact and
  parts that rest on documented approximations.
- `$warnings` -- quality-control flags in plain language.
- `$population` -- present only when `routes` is supplied to `burden_report()`:
  the same shape as `$burden`, weighted by observed respondent routes.

Single-number results, such as `points_per_minute`, `rare_threshold` and the
benchmark, are stored as attributes on the object. `summary(report)` prints a
one-line headline. The full component list is in `?burden_report`.

## The two-paper split (settled)

The work divides into two papers.

The first is the package paper, for JOSS. Its scope is structural burden
measurement and allocation, computed from a Qualtrics instrument alone. It makes
no use of paradata. It makes no causal claim, no claim that burden drives
dropout or satisficing, and no claim about time calibration. The points-to-minutes
figure is described only as the published GfS rule of thumb, roughly 12 points
per minute, user-overridable.

The second is a separate, later paper on calibration and respondent behaviour.
Those results are out of scope for this document.

## What is validated

- Flow reconstruction has been checked against a fielded web survey. Every
  observed respondent's routing corresponded to one of the enumerated structural
  paths.
- A synthetic fixture exercises question types and flow structures beyond the
  worked example.
- The package has an automated test suite, currently green with no skips.
- Plain `R CMD check` on the built tarball is clean.

## The fielded web survey

The survey used to check flow reconstruction is referred to generically as "a
fielded web survey". It is not named in any public artefact, pending the study
team's permission. Its paradata and its QSF are not distributed with the package.

## Known limitations

- The Qualtrics-to-GfS mapping is sometimes inferential. Where a widget has no
  exact match in the scheme, a documented rule is applied and the question is
  flagged.
- The GfS scheme predates modern web survey interfaces.
- Rendered text length cannot be recovered from a `.qsf`. The file stores words,
  not an on-screen line count, so `words_per_line` is a configurable proxy.
- Display-logic reconstruction depends on what the `.qsf` encodes. Logic
  controlled outside Qualtrics, or unusual constructs, may need manual
  interpretation.
- Structural enumeration gives no respondent probabilities. Without route data,
  every feasible combination is counted once, and "median" means the median
  across combinations, not across respondents.
- Loop and Merge can make the path space large. The package unrolls to the
  explicit cap and treats the iteration count as uniform.
- The points-to-minutes conversion is the GfS rule of thumb, not a
  completion-time prediction.
- Burden scores are not predictions of completion time, dropout or satisficing.

## Status

- On GitHub at `github.com/pmpk20/surveyBurden`.
- Not on CRAN.
- Test suite green, no skips.
- Plain `R CMD check` on the tarball is clean. `devtools::check()` needs a local
  `rlang >= 1.2.0`, which is unrelated to the package.
- Next step: JOSS submission.

## How to use this document

This is the current-state briefing: hand it to a reviewer or an assistant to get oriented without the development history.
