---
title: 'surveyBurden: path-aware ex-ante survey instrument burden from a Qualtrics definition'
tags:
  - R
  - survey methodology
  - respondent burden
  - questionnaire design
  - Qualtrics
authors:
  - name: Peter King
    orcid: 0000-0001-8550-466X
    affiliation: 1
affiliations:
  - name: Institute for Transport Studies, University of Leeds, United Kingdom
    index: 1
date: 7 September 2026
bibliography: paper.bib
---

# Summary

`surveyBurden` is an R package [@rcore] that estimates the response burden of a
survey instrument before it is fielded, directly from its machine-readable
definition. It reads a Qualtrics survey, either a `.qsf` export or a live
definition pulled through the Qualtrics API, reconstructs the respondent paths
that the survey flow and display logic allow, and applies the published GfS /
Axhausen item burden-scoring scheme [@schmid2019; @heimgartner2024] to every
question on every path. It then reports how burden is distributed across the
whole structural path space: an achievable minimum, quartiles, median and
maximum in GfS points, the share contributed by each block, the highest-burden
questions, and a set of quality-control diagnostics. A single call,
`burden_report("survey.qsf")`, runs the whole pipeline. Lower-level functions
expose each step, from parsing through question scoring, flow resolution and
path enumeration, for inspection or reuse.

The result is a structured object rather than printed text, so each component
can be extracted and analysed on its own. A Qualtrics definition does not
contain everything the scoring scheme needs, so the package keeps two kinds of
quantity apart: those the scheme specifies directly, such as question type,
response action and the number of alternatives, and those it has to infer, such
as approximate line counts and response-unit structure. Every question's score
is labelled with the rule that produced it.

# Statement of need

Response burden is a central construct in survey methodology. It is associated
with nonresponse and breakoff, and reducing it is a routine design goal
[@yan2022; @yan2008]. Yet burden is still usually assessed by hand, with an
analyst reading through the questionnaire and forming a judgement, or it is
reduced to a single length or duration figure for an "average" respondent.

Contemporary web surveys make that inadequate. Conditional routing, branch logic
and question-level display logic mean that different respondents complete
materially different instruments: the questions asked, their number and their
difficulty all vary with earlier answers. A burden assessment that treats the
instrument as a fixed sequence describes a path that few respondents take.

Tools exist to read Qualtrics definitions in R. The `qualtRics` package
[@qualtRics] retrieves survey metadata and responses, and the GfS / Axhausen
framework provides published item weights [@schmid2019; @heimgartner2024].
However, we are not aware of an open-source tool that connects a machine-readable
survey definition to established burden scoring in a path-aware way,
reconstructing the feasible respondent paths and reporting how burden is
distributed across them. `surveyBurden` is aimed at survey methodologists and
applied researchers who want a transparent, reproducible burden assessment at
the design stage, and at anyone auditing an instrument that has already been
programmed.

# Functionality

- **Qualtrics ingestion.** `read_qsf()` accepts a `.qsf` path, a bare survey id,
  or a survey-builder URL. `fetch_qsf()` pulls a live definition through the
  Qualtrics API. Both are normalised to one internal representation, and
  `parse_qsf()` produces a question catalogue.
- **GfS scoring, with the inference made explicit.** `gfs_weights()` holds the
  GfS / Axhausen point weights. `score_burden()` then works in three layers:
  what Qualtrics records the question as, what response action that implies, and
  which scheme category best represents that action. Where the structure fixes
  the mapping, the score is marked `auto`. Where the definition does not contain
  what the scheme needs, for example a dropdown that has no matching category or
  rendered lines of text that a `.qsf` does not store, the package applies a
  documented, configurable inference rule and marks the question `inferred`.
  Genuinely undetermined questions are left unscored and flagged for a human.
  Every question carries a `score_flag` and a `score_basis` string recording
  which rule was applied and why.
- **Flow reconstruction.** `resolve_flow()` enumerates the block sequences that
  the survey flow permits, forking at each branch and screen-out without
  evaluating the branch conditions.
- **Display-logic handling.** `resolve_paths()` partitions the questions on each
  path into always shown, possibly shown, and never shown, folding grouped
  If / ElseIf conditions into a single feasibility statement per question.
- **Path enumeration.** `path_burden_profile()` enumerates the feasible burden
  values within each path by resolving display-logic gates, exactly for small
  coupling components and with a documented approximation for large ones. The
  result is a profile of feasible burden values, each counted once, and is not a
  probability distribution over respondents. When observed respondent routes are
  supplied, `respondent_burden()` weights each route by how often it occurs and
  returns a population-weighted average.
- **Structured report.** `burden_report()` returns an object whose components
  include the instrument summary, the burden spread, the per-block and per-path
  breakdowns, the scored question catalogue, the calculation-certainty summary,
  and the readability diagnostics. Printing the object renders a formatted
  report; `summary()` gives a one-line headline.
- **Diagnostics.** The report keeps readability signals (long question stems,
  long response labels, long grids) separate from the GfS score, flags large
  screen-out shares, and states, for the given survey, which parts of the
  calculation are exact and which rest on documented approximations. The
  points-to-minutes conversion uses the GfS rule of thumb of roughly 12 points
  per minute and is user-configurable.

The package includes an automated test suite and passes `R CMD check` cleanly.

# Validation

The flow reconstruction has been checked against a fielded web survey, and every
observed respondent's routing corresponded to one of the enumerated structural
paths. A synthetic fixture exercises question types and flow structures beyond
the worked example.

# Acknowledgements

[Funder and acknowledgements to be confirmed.]

# References
