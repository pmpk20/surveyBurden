---
title: 'surveyBurden: Calculation of the response burden of Qualtrics surveys'
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
date: 10 September 2026
bibliography: paper.bib
---

# Summary

`surveyBurden` is an R package [@rcore] that reports how difficult a survey is. Specifically, it estimates the response burden of a survey programmed in Qualtrics, measured with the GfS item burden-scoring scheme [@schmid2019; @heimgartner2024]. The package works with either a `.qsf` export or a live survey pulled through the Qualtrics API. The package then calculates the response burden in three steps. Firstly, it reconstructs every permutation of the paths through the survey that the flow and display logic allow. Secondly, it assigns the GfS points to every question on every path. Finally, it calculates how response burden is distributed across all the structural paths and reports the achievable minimum and maximum, quartiles, and the median burden in GfS points. For more insight, we also report the share of total response burden contributed by each block in the survey, and the highest-burden questions. Where the package infers a score, through an assumed line count for example, it explicitly labels the response.
The entire pipeline can be run via a single call, `burden_report("survey.qsf")`, but lower-level functions to tackle each step, from parsing through question scoring, flow resolution and path enumeration, are provided for inspection or reuse. The result of `burden_report("survey.qsf")` is a structured object so that each component can be extracted and analysed on its own.


# Statement of need
Response burden is a central construct in survey methodology. It is associated with nonresponse and breakoff, and reducing it is a routine design goal
[@yan2022; @yan2008]. Yet burden is still imprecisely understood, either through completion length or crudely summing the number of questions, which reduces response burden to a single length or duration figure for an "average" respondent. Contemporary web surveys make that inadequate. Conditional routing, branch logic and question-level display logic mean that different respondents complete materially different surveys: the questions asked, their number and their difficulty all vary with earlier answers. A burden assessment that treats the survey as a fixed sequence describes a path that few respondents take. The automation of response burden scoring across all questions and paths represents a significant step-change in the ability to understand how difficult a survey is.

While tools exist to read Qualtrics surveys into R, neither they, nor Qualtrics, transparently calculate and report the respondent burden. The `qualtRics` package
[@qualtRics] retrieves survey metadata and responses, and the GfS framework
provides published item weights [@schmid2019; @heimgartner2024].
However, we are not aware of an open-source tool that connects a machine-readable
survey to established burden scoring in a path-aware way,
reconstructing the feasible respondent paths and reporting how burden is
distributed across them. `surveyBurden` is aimed at survey methodologists and
applied researchers who want a transparent, reproducible burden assessment at
the design stage, and at anyone auditing a survey that has already been
programmed.

# Functionality

- **Qualtrics import.** `read_qsf()` accepts a `.qsf` path, a bare survey id,
  or a survey-builder URL. `fetch_qsf()` pulls a live survey through the
  Qualtrics API. Both are normalised to one internal representation, and
  `parse_qsf()` produces a question catalogue. Fetching a live survey needs an API key for the account that owns it.
- **GfS scoring, with the inference made explicit.** `gfs_weights()` holds the
  GfS point weights. `score_burden()` then works in three layers:
  what Qualtrics records the question as, what response action that implies, and
  which scheme category best represents that action. Where the structure fixes
  the mapping, the score is marked `auto`. Where the survey does not contain
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
  result is a profile of feasible burden values, each counted once. It is not a
  probability distribution over respondents! However, when observed respondent routes are
  supplied, `respondent_burden()` weights each route by how often it occurs and
  returns a population-weighted average.
- **Structured report.** `burden_report()` returns an object whose components
  include the survey summary, the burden spread, the per-block and per-path
  breakdowns, the scored question catalogue, the calculation-certainty summary,
  and the readability diagnostics. Printing the object renders a formatted
  report; `summary()` gives a one-line headline.
- **Diagnostics.** The report keeps readability signals (long question stems,
  long response labels, long grids) separate from the GfS score, flags large
  screen-out shares, and states, for the given survey, which parts of the
  calculation are exact and which rest on documented approximations. We use the twelve points per minute (12pts/min) rule of thumb from [@schmid2019] to provide an estimated completion time, but users may reconfigure this if desired.

The package includes an automated test suite and passes `R CMD check` cleanly.

# Validation

The flow reconstruction has been checked against a fielded web survey, and every
observed respondent's routing corresponded to one of the enumerated structural
paths. 

# Acknowledgements

This work was supported by the Engineering and Physical Sciences Research Council INFUZE project (grant number: EP/Z531273/1).

# References
