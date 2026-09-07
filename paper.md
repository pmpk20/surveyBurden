---
title: 'surveyBurden: path-aware ex-ante survey burden from a Qualtrics survey'
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
date: 8 September 2026
bibliography: paper.bib
---

# Summary

`surveyBurden` is an R package [@rcore] that estimates the response burden of a
survey from its design alone, with no response data. Qualtrics is a widely used
commercial survey platform; a Qualtrics survey exports as a `.qsf` file, which
is JSON. `surveyBurden` reads a `.qsf` file, or a live survey through the
Qualtrics API, reconstructs the respondent paths that the survey's flow and
display logic permit, and applies the published GfS / Axhausen item
burden-scoring scheme [@schmid2019; @heimgartner2024], hereafter "GfS points",
to every question on every path. Because it needs only the survey design, it can
be run before fielding to compare design options, or afterwards to audit an
instrument already in the field.

`burden_report("survey.qsf")` runs the whole pipeline and returns a structured
object. It reports the burden across the full set of paths the flow and display
logic allow — the minimum, quartiles, median and maximum in GfS points — and,
for the instrument as a whole, the share of burden contributed by each block,
the highest-burden questions, and quality-control diagnostics. These path
summaries count each feasible path once; supplying observed respondent routes
turns them into population-weighted figures. Lower-level functions expose each
step — parsing, question scoring, flow resolution, path enumeration — for
inspection or reuse.

Assigning a GfS score needs the question type, response action and number of
answer options, which a `.qsf` provides, and the number of rows in a grid or
options in a list, and the on-screen length of instruction text, which it does
not. Where the `.qsf` is missing what the scheme needs, the package applies a
documented, configurable rule — for example, scoring a dropdown as a rating, or
estimating text length from a word count — and labels the question `inferred`
rather than `auto`, with a string recording which rule was used. Questions that
cannot be resolved are left unscored and flagged for a human.

# Statement of need

Response burden is a central construct in survey methodology. It has an
objective side — the length, question types and effort a survey demands — and a
perceived side, how burdensome respondents find it [@yan2022]. `surveyBurden`
scores the objective side. Objective burden is associated with nonresponse and
dropout, and with satisficing behaviour such as speeding and straightlining
among respondents who continue [@tourangeau2018; @peytchev2009], though the
evidence is mixed, and reducing it is a routine design goal. Yet it is still
usually assessed by hand — an analyst reading through the questionnaire and
forming a judgement — or reduced to a single length or duration for an
"average" respondent.

Contemporary web surveys make that inadequate. Conditional routing, branch logic
and question-level display logic mean that different respondents complete
materially different instruments: the questions asked, their number and their
difficulty all vary with earlier answers. A burden assessment that treats the
instrument as a fixed sequence describes a path that few respondents take.

Existing tools address adjacent tasks. The `qualtRics` package [@qualtRics]
retrieves survey metadata and responses but not the branching structure needed
to reconstruct respondent paths. Question-characteristic coding schemes such as
the Survey Quality Predictor [@saris2014] rate items for measurement quality
rather than response effort, and are applied by hand. The GfS / Axhausen
framework [@axhausen2015; @schmid2019; @heimgartner2024] provides published item
weights but is normally computed manually and reported as a single
instrument-level figure; @calastri2020 apply it to one multi-component travel
survey and note that it cannot be applied where the number of questions a
respondent receives depends on their own answers. We are not aware of an
open-source tool that connects a machine-readable survey to established burden
scoring in a path-aware way, reconstructing the feasible respondent paths and
reporting how burden is distributed across them. `surveyBurden` is aimed at
survey methodologists and applied researchers who want a transparent,
reproducible burden assessment at the design stage, and at anyone auditing an
instrument that has already been programmed.

# Functionality

The pipeline has four stages, each with exposed functions. **Ingestion:**
`read_qsf()` accepts a `.qsf` path, a survey id or a survey-builder URL;
`fetch_qsf()` pulls a live survey through the API; `parse_qsf()` produces a
question catalogue. **Scoring:** `gfs_weights()` holds the point weights and
`score_burden()` maps each question to a scheme category, marking every score
`auto` or `inferred`. **Path reconstruction:** `resolve_flow()` enumerates the
block sequences the survey flow permits, forking at each branch without
evaluating conditions; `resolve_paths()` classifies each question on a path as
always, possibly or never shown; `path_burden_profile()` enumerates the feasible
burden values within each path, exactly for small display-logic components and
with a documented approximation for large ones. **Reporting:**
`respondent_burden()` weights paths by observed routes when supplied, and
`burden_report()` assembles the structured report, whose components include the
instrument summary, the burden spread, per-block and per-path breakdowns, the
scored question catalogue, a calculation-certainty summary, and readability
diagnostics (long stems, long response labels, long grids) kept separate from
the GfS score. The points-to-minutes conversion uses the GfS rule of thumb of
roughly twelve points per minute and is user-configurable.

The package is around 1,500 lines of R with 166 unit tests, and passes
`R CMD check` cleanly on Linux, macOS and Windows. The flow reconstruction has
been checked against a large fielded web survey — every completed respondent's
routing corresponded to an enumerated structural path, and feeding respondents'
answers through the display logic reproduced which questions they were shown
with 98% agreement — and a companion methods paper reports this validation in
full.

# Acknowledgements

[Funder and acknowledgements to be confirmed.]

# References
