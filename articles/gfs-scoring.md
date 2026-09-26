# The GfS+ scoring method

This article covers how one Qualtrics question becomes a GfS+ point
score. For how those scores are combined across the survey’s routes see
[`vignette("paths-and-display-logic")`](https://pmpk20.github.io/surveyBurden/articles/paths-and-display-logic.md);
for reading the finished report see
[`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md).

``` r

library(surveyBurden)
demo <- system.file("extdata", "demo_travel_survey.qsf", package = "surveyBurden")
qsf <- read_qsf(demo)
catalogue <- parse_qsf(qsf)
```

surveyBurden implements and extends the published GfS scheme
(Heimgartner and Axhausen 2024, Table 1). The original point weights are
transcribed verbatim into
[`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md);
the package adds documented inference rules for Qualtrics question types
that have no row in the original table, hence GfS+.

``` r

w <- gfs_scheme()
w$yes_no
#> [1] 1
w$rating_small
#> [1] 2
w$rating_large
#> [1] 3
w$points_per_minute
#> [1] 12
```

A few of the Table 1 weights, in points per response action:

| response action                    | GfS+ points                    |
|------------------------------------|--------------------------------|
| yes / no question                  | 1                              |
| rating scale, up to 5 options      | 2                              |
| rating scale, more than 5 options  | 3                              |
| first answer to an open question   | 6                              |
| two-alternative stated-choice task | 2 (reference only – see below) |

The full table is in Heimgartner and Axhausen (2024); it is not
reproduced here.
[`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
transcribes every Table 1 weight, but the automatic scorer does not use
all of them – see [What the automatic scorer
applies](#what-the-automatic-scorer-applies).

## Classification first

[`classify_question()`](https://pmpk20.github.io/surveyBurden/reference/classify_question.md)
maps each Qualtrics widget to a standard question type. The Qualtrics
type alone is not enough: one `MC` widget can be a yes/no item, a rating
scale, a dropdown, or a multi-select, depending on its selector and
options.

``` r

table(catalogue$std_type)
#> 
#>   descriptive        matrix  multi_choice     open_text single_choice 
#>             1             4             1             3            17
```

## Three layers

[`score_burden()`](https://pmpk20.github.io/surveyBurden/reference/score_burden.md)
then works in three layers:

1.  what Qualtrics says the widget is (for example `MC` with a dropdown
    selector);
2.  what response action that implies (choose one value from an ordered
    list);
3.  which Table 1 category best represents that action (a rating).

Where step 3 is fixed by the structure – a two-option choice is a closed
yes/no item whatever it asks – the mapping is deterministic and the
score is marked `auto`. Where the `.qsf` does not carry what the scheme
needs, the package applies an **explicit, documented inference rule**
and marks the item `inferred`. Every scored question carries a
`score_basis` string recording the rule applied.

``` r

scored <- score_burden(catalogue, scheme = w)
table(scored$score_flag)
#> 
#>     auto inferred 
#>       19        7
head(scored[order(-scored$gfs_points),
            c("question_id", "std_type", "gfs_points", "score_flag", "score_basis")])
#> # A tibble: 6 × 5
#>   question_id std_type     gfs_points score_flag score_basis                    
#>   <chr>       <chr>             <dbl> <chr>      <chr>                          
#> 1 QID21       matrix               18 auto       matrix, 6 rows x GfS rating >5…
#> 2 QID19       matrix               14 auto       matrix, 7 rows x GfS rating <=…
#> 3 QID14       multi_choice         12 auto       multi-select, 6 options -> GfS…
#> 4 QID20       matrix               12 auto       matrix, 6 rows x GfS rating <=…
#> 5 QID1        descriptive          11 inferred   transition/instruction text: 1…
#> 6 QID7        matrix                8 auto       matrix, 4 rows x GfS rating <=…
```

`score_flag` has four values:

- `auto` – the GfS+ mapping is deterministic from the structure.
- `inferred` – the structure is clear, but choosing the Table 1 category
  involved an explicit judgement (a dropdown mapped to “rating” as the
  closest category, a numeric-looking dropdown mapped to “simple
  numerical answer”, a slider). The number is still determinate.
- `manual` – a human should check; the mapping is genuinely uncertain.
- `unknown` – an unmapped type, left unscored as `NA`. A survey with
  unknown types produces an under-count, and
  [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  warns.

This is the distinction between **GfS-native** quantities (from the
original scheme: question type, response action, number of alternatives
– all specified by the scheme) and **package-derived** ones (estimated
line counts, response-unit structure – inferred because the `.qsf` lacks
them).

## Documented inference rules where Table 1 is silent

- **Instruction-text lines.** Table 1 counts rendered “lines” of
  instruction text. A `.qsf` stores words, not a rendered width, so
  lines are estimated as words / `words_per_line` (default 12). This is
  a pragmatic conversion heuristic, not a calibrated constant; override
  it with `burden_report(words_per_line = ...)`. See
  [`vignette("calibration")`](https://pmpk20.github.io/surveyBurden/articles/calibration.md).
- **Dropdowns** (`MC` with a `DL` selector) have no Table 1 row. They
  are scored as a rating (2.0 for up to 5 options, 3.0 for more), or as
  a simple numerical answer (1.0) when the options are numbers and the
  question asks for a quantity or a date.
- **Sliders** are not in Table 1. They are scored as a numerical answer
  when the axis label carries units, otherwise as a rating.
- **Hidden questions.** A question hidden from the respondent by
  injected CSS or JavaScript scores 0.
- **Loop & Merge blocks.** Item scores are per iteration; the
  multiplication happens later, when paths are scored. The structural
  profile spreads each loop’s iteration count evenly over 1 to the
  block’s explicit cap (never 0); the naive ceiling uses the cap and the
  naive floor one iteration. A loop with no explicit cap is not
  multiplied at all – its questions count once – which can understate
  the upper figures. Within-loop display logic is not enumerated.

### Question stems are not separately scored

The GfS Table 1’s “question or transition, up to 3 lines = 2.0” is
applied to standalone instruction blocks only, not the question text
itself! It is unclear whether the GfS scheme intended the reading cost
of a question to be absorbed into the item weight or counted separately.
A question with a long disambiguation stem is, therefore, scored
conservatively, and its stem length is reported separately as a
readability diagnostic (see
[`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md)).

### Multi-answer matrices have no Table 1 rule

A grid where each cell allows multiple answers – “tick all that apply”
across two axes – is scored as `rows x cols x 0.5`. Each cell is one
trivial closed yes/no decision; GfS scores a closed yes/no at 1.0,
discounted here for the working-memory efficiency of answering in a
grid. This proxy is symmetric in rows and columns so it does not change
with how Qualtrics happened to store the grid. It is a GfS+ extension,
not part of the original GfS table. The weight is
`gfs_scheme()$matrix_cell_multi`.

## What the automatic scorer applies

Each standard question type gets one rule. This table is the complete
list; `score_basis` names the rule used for each question.

| Question type (`std_type`) | Automatic rule | Scheme entries used | Flag |
|----|----|----|----|
| `single_choice`, 2 options | closed yes/no | `yes_no` | auto |
| `single_choice`, 3-5 / 6+ options | rating | `rating_small` / `rating_large` | auto |
| `single_choice`, option count unknown | assumed a rating up to 5 | `rating_small` | inferred |
| dropdown | rating by option count; a simple numerical answer when the options are numbers and the question asks for a quantity or date | `rating_small`, `rating_large`, `numeric_answer` | inferred |
| `multi_choice`, n options | half-open: base + per extra option, switching at `multi_large_threshold` | `multi_small_*`, `multi_large_*` | auto |
| `matrix`, single answer per row | rows x rating by column count | `rating_small` / `rating_large` | auto |
| `matrix`, multiple answers per row | rows x cols x cell weight | `matrix_cell_multi` | inferred |
| `open_text`, single line | answer of up to 5 words | `open_short` | auto |
| `open_text`, multi-line | first answer to an open question | `open_essay` | auto |
| `slider` | numerical answer when the label has units, else a rating | `numeric_answer`, `slider` | inferred |
| `ranking` | best-of ranking, first item only | `rank_base` | auto |
| `constant_sum` | numerical answer | `numeric_answer` | inferred |
| `descriptive` | base + per line beyond 3, lines = words / `words_per_line` | `descriptive_*`, `words_per_line` | auto |
| `captcha` | fixed small cost | `captcha` | auto |
| `timing`, `meta`, or hidden by CSS/JS | 0 | – | auto / inferred |
| anything else | not scored: `NA`, counted as 0 in totals | – | unknown |

**Reference-only entries.** These Table 1 weights are in
[`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
for completeness, but no automatic rule reads them, so changing them
does not change any score: `rank_per_item`, `open_medium`,
`please_specify`, `open_essay_per_extra`, `filter`, `branching`,
`sc_2_alt`, `sc_3_alt` and `sc_per_variable`. In practice:

- a ranking scores its first item only, so rankings of several items are
  under-scored;
- stated-choice tasks, “please specify” boxes and repeated open answers
  are scored as whatever widget Qualtrics used for them (a single
  choice, a text box), not with the stated-choice or follow-up weights;
- branching and filter points are not added.

Where your survey has these, check the affected questions’ `score_basis`
and adjust by hand if needed.

**What can make the reported figures too low.** Unscored (`unknown`)
questions contribute 0, loops without an explicit cap are counted once,
and the reference-only items above are under-scored.
[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
warns about unscored questions;
[`calculation_certainty()`](https://pmpk20.github.io/surveyBurden/reference/calculation_certainty.md)
counts loops with unknown caps.

## Overriding the weights

Every weight in
[`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
can be changed and passed back in; only the entries a rule uses (table
above) affect scores:

``` r

w2 <- gfs_scheme()
w2$rating_small <- 2.5
score_burden(catalogue, scheme = w2)$gfs_points[1:5]
#> [1] 11.0  1.0  2.5  1.0  2.5
```

## References

- Heimgartner, D. and Axhausen, K. W. (2024). Predicting response rates
  once again. *Findings*.
  <https://findingspress.org/article/125481-predicting-response-rates-once-again>
