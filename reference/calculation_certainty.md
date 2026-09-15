# Where the burden calculation is exact, and where it rests on assumptions

[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
propagates an established item score through a survey's flow and display
logic. Some of that propagation is exact (a fixed block sequence, a loop
with an explicit cap); some rests on documented assumptions (the
gate-independence approximation for large display-logic components, the
independence of separate coupling components). This function reports the
split so a reader can see which parts of the output to trust fully and
which to read as assumption-dependent.

## Usage

``` r
calculation_certainty(
  qsf,
  weights = gfs_weights(),
  max_paths = 10000L,
  paths = NULL,
  scored = NULL,
  blocks = NULL,
  parsed_dl = NULL
)
```

## Arguments

- qsf:

  A path to a `.qsf`, or a `qsf_raw` object from
  [`read_qsf()`](https://pmpk20.github.io/surveyBurden/reference/read_qsf.md).

- weights:

  A
  [`gfs_weights()`](https://pmpk20.github.io/surveyBurden/reference/gfs_weights.md)
  list.

- max_paths:

  Passed to
  [`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md).

- paths, scored, blocks, parsed_dl:

  Optional precomputed
  [`resolve_paths()`](https://pmpk20.github.io/surveyBurden/reference/resolve_paths.md),
  [`score_burden()`](https://pmpk20.github.io/surveyBurden/reference/score_burden.md),
  [`resolve_live_blocks()`](https://pmpk20.github.io/surveyBurden/reference/resolve_live_blocks.md)
  and parsed display-logic results for this `qsf` (internal reuse by
  [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md);
  `NULL` computes them here, leaving the public behaviour unchanged).

## Value

An object of class `calculation_certainty` (list):

- paths:

  `n_full`, `n_exact` (no unresolved display-logic conditions),
  `n_with_unresolved`, and a `per_path` tibble.

- branches:

  One row per flow `Branch`, with the trigger variable(s). Both outcomes
  of every branch are always enumerated, so a branch is not an
  approximation – but which outcome a given respondent takes is unknown
  ex ante.

- display_logic:

  `n_conditional` questions gated by an unresolved condition on some
  full path; `n_exact` scored by exact joint enumeration of their gate
  states; `n_approx` scored with the primary-gate approximation;
  component counts; and `cross_component_independence` (`TRUE` when \>1
  coupling component is convolved as independent).

- loops:

  `n_known` loop blocks with an explicit iteration cap, `n_unknown` with
  a dynamic/unknown bound, and a `bounds` tibble.

- scores:

  Counts of `score_flag`: `auto` (confident structural mapping),
  `inferred` (mapping needs an assumption), `manual`, `unknown`.

## Examples

``` r
# \donttest{
qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
                         package = "surveyBurden")
calculation_certainty(qsf_path)
#> 
#> ── Calculation certainty: Neighbourhood Travel Survey (demo) ───────────────────
#> 
#> ── Paths ──
#> 
#> 0 of 2 complete paths resolve exactly (no unresolved display-logic condition);
#> 2 carry at least one.
#> 3 flow branches; both outcomes of each are enumerated, but which one a given
#> respondent takes is unknown ex ante:
#> FL_b_consent: trigger QID2
#> FL_b_area: trigger QID3
#> FL_b_work: trigger QID6
#> 
#> ── Display logic ──
#> 
#> 6 conditional questions on some path: 6 scored by exact joint enumeration, 0
#> with the primary-gate approximation.
#> 4 coupling components (4 exact, 0 approximated).
#> Separate components are convolved as independent (assumption).
#> 
#> ── Loops ──
#> 
#> 2 loop blocks with an explicit iteration cap; 0 with a dynamic/unknown bound.
#> Other adults: 0-5 iterations
#> Vehicle details: 0-3 iterations
#> 
#> ── Item scores ──
#> 
#> 19 scored with full confidence (auto); 7 by structural inference (inferred); 0
#> need manual verification; 0 unmapped.
# }
```
