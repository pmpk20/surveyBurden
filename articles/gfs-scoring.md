# The GfS+ scoring method

**What this answers.** How one question becomes a GfS+ point score, and
which rule applies to each question type.

**What you need.** A `.qsf`, or a question catalogue (see
[`vignette("extensions")`](https://pmpk20.github.io/surveyBurden/articles/extensions.md)).

**What to keep in mind.** Scores are per question and per loop
iteration, and routing is applied later. The rules map each question
onto the published scheme, which weighs response tasks by type and
complexity. A few Table 1 weights apply only when you set them by hand.

For how scores combine across the survey’s paths see
[`vignette("paths-and-display-logic")`](https://pmpk20.github.io/surveyBurden/articles/paths-and-display-logic.md).
For reading the finished report see
[`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md).

``` r

library(surveyBurden)
#> 
#>                   .-- Q2 -- Q3 --.
#>   survey -- Q1 --+               +-- Burden 0.3.0
#>                   '-- Q4 --------'
#> 
#> Measuring the Response Burden of Web Surveys
#> Docs: https://pmpk20.github.io/surveyBurden/
#> 
#> Please cite: King P (2026). surveyBurden: Measuring the Response Burden
#> of Web Surveys. R package version 0.3.0,
#> https://github.com/pmpk20/surveyBurden.
#> Use citation("surveyBurden") for BibTeX.
demo <- system.file("extdata", "demo_travel_survey.qsf", package = "surveyBurden")
qsf <- read_qsf(demo)
catalogue <- parse_qsf(qsf)
```

## Where the scheme comes from

GfS stands for Gesellschaft für Sozialforschung (Society for Social
Research), a Zürich organisation that used a point system to budget
face-to-face interviews. Axhausen and colleagues adapted it to
self-administered surveys. Each question earns points by its type and
complexity, and the points are added up, so longer or more complex
surveys score higher (Schmid and Axhausen 2019). The survey literature
calls this kind of measure objective burden, the work a survey asks of
respondents measured from the questions themselves (Yan and Williams
2022).

surveyBurden transcribes the current table (Heimgartner and Axhausen
2024, Table 1) verbatim into
[`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md).
It adds documented rules for Qualtrics question types that the table
lacks, hence GfS+.

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

| response action | GfS+ points |
|----|----|
| yes / no question | 1 |
| rating scale, up to 5 options | 2 |
| rating scale, more than 5 options | 3 |
| first answer to an open question | 6 |
| two-alternative stated-choice task | 2, plus 1 per attribute (declared tasks only, see below) |

Heimgartner and Axhausen (2024) give the full table.
[`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
holds every Table 1 weight, and the automatic scorer uses most of them.
[What the automatic scorer applies](#what-the-automatic-scorer-applies)
lists which.

## Classification first

[`classify_question()`](https://pmpk20.github.io/surveyBurden/reference/classify_question.md)
maps each Qualtrics widget to a standard question type. It reads the
widget’s selector and options as well as its type, because one `MC`
widget can be a yes/no item, a rating scale, a dropdown or a
multi-select.

``` r

table(catalogue$std_type)
#> 
#>   descriptive        matrix  multi_choice     open_text single_choice 
#>             1             4             1             3            17
```

## Three layers

[`score_burden()`](https://pmpk20.github.io/surveyBurden/reference/score_burden.md)
then works in three layers.

1.  What Qualtrics says the widget is (for example `MC` with a dropdown
    selector).
2.  What response action that implies (choose one value from an ordered
    list).
3.  Which Table 1 category best represents that action (a rating).

Where the structure fixes step 3 (a two-option choice is a closed yes/no
item whatever it asks), the mapping is deterministic and the score is
marked `auto`. Where the scheme needs something the `.qsf` lacks, the
package applies an **explicit, documented inference rule** and marks the
item `inferred`. Every scored question carries a `score_basis` string
recording the rule applied.

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

`score_flag` takes four values.

- `auto` means the structure fixes the GfS+ mapping.
- `inferred` means the structure is clear and choosing the Table 1
  category took an explicit judgement (a dropdown mapped to “rating” as
  the closest category, a numeric-looking dropdown mapped to “simple
  numerical answer”, a slider). The number is still determinate.
- `manual` means the mapping is uncertain and a person should check it.
- `unknown` marks an unmapped type, left unscored as `NA`. A survey with
  unknown types is under-counted, and
  [`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
  warns about it.

The flags separate **GfS-native** quantities, which the original scheme
specifies (question type, response action, number of alternatives), from
**package-derived** ones, which the package estimates because the `.qsf`
lacks them (line counts, response-unit structure).

## Documented inference rules for gaps in Table 1

- **Instruction-text lines.** Table 1 counts rendered lines of
  instruction text. A `.qsf` stores words, so the package estimates
  lines as words / `words_per_line` (default 12). This is a practical
  conversion that you can override with
  `burden_report(words_per_line = ...)`. See
  [`vignette("calibration")`](https://pmpk20.github.io/surveyBurden/articles/calibration.md).
- **Dropdowns** (`MC` with a `DL` selector) lack a Table 1 row. They
  score as a rating (2.0 for up to 5 options, 3.0 for more), or as a
  simple numerical answer (1.0) when the options are numbers and the
  question asks for a quantity or a date.
- **Sliders** also lack a Table 1 row. They score as a numerical answer
  when the axis label carries units, and as a rating otherwise.
- **Hidden questions.** A question hidden from the respondent by
  injected CSS or JavaScript scores 0.
- **Loop & Merge blocks.** Item scores are per iteration, and the
  multiplication happens later, when paths are scored. The structural
  profile spreads each loop’s iteration count evenly from 1 to the
  block’s explicit cap. The naive ceiling uses the cap and the naive
  floor one iteration. A loop without an explicit cap counts its
  questions once, which can understate the upper figures. Display logic
  inside a loop is left unenumerated.

### Question stems

Table 1’s “question or transition, up to 3 lines = 2.0” applies to
standalone instruction blocks only. The question text itself earns no
separate points, because the GfS scheme leaves unclear whether a
question’s reading cost belongs in the item weight or on its own. A
question with a long stem is therefore scored conservatively, and its
stem length appears separately as a readability diagnostic (see
[`vignette("reading-the-report")`](https://pmpk20.github.io/surveyBurden/articles/reading-the-report.md)).

### Multi-answer matrices

Table 1 has no rule for a grid where each cell allows several answers
(“tick all that apply” across two axes). surveyBurden scores it as
`rows x cols x 0.5`. Each cell is one simple yes/no decision, which GfS
scores at 1.0, discounted here because answering in a grid takes less
working memory. The formula is symmetric in rows and columns, so the
score stays the same however Qualtrics stored the grid. This rule is a
GfS+ extension, and its weight is `gfs_scheme()$matrix_cell_multi`.

## What the automatic scorer applies

Each standard question type gets one rule. This table is the complete
list, and `score_basis` names the rule used for each question.

| Question type (`std_type`) | Automatic rule | Scheme entries used | Flag |
|----|----|----|----|
| `single_choice`, 2 options | closed yes/no | `yes_no` | auto |
| `single_choice`, 3-5 / 6+ options | rating | `rating_small` / `rating_large` | auto |
| `single_choice`, option count unknown | assumed a rating up to 5 | `rating_small` | inferred |
| dropdown | rating by option count, or a simple numerical answer when the options are numbers and the question asks for a quantity or date | `rating_small`, `rating_large`, `numeric_answer` | inferred |
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
| `timing`, `meta`, or hidden by CSS/JS | 0 |  | auto / inferred |
| anything else | left as `NA`, counted as 0 in totals |  | unknown |

**Stated-choice tasks.** A QSF stores a choice task as an ordinary
widget, so the scorer treats it as that widget (usually a single
choice). Declare your tasks with `choice_tasks`, a data frame of
`question_id`, `n_alternatives` and `n_attributes`, in
[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
or any other burden function. Each declared task scores 2 points for two
alternatives, 3 for three and 1 more for each alternative beyond three
(an extrapolation past Table 1), plus 1 per attribute
(`sc_per_variable`). Count an opt-out such as “neither” as an
alternative.
[`suggest_choice_tasks()`](https://pmpk20.github.io/surveyBurden/reference/suggest_choice_tasks.md)
lists questions that look like choice tasks (an HTML table in the stem)
for you to check before you declare them.

**Filter and branching points.** GfS adds 0.5 for a filter and 0.5 for a
branching. GfS budgets interviewer-administered surveys, where the
interviewer applies each filter. In a web survey the software applies
them, so these points are off by default
(`apply_filter_branching = FALSE`). Set
`s$apply_filter_branching <- TRUE` to match a manual GfS count. A
question then earns 0.5 if its answer drives another question’s display
logic and 0.5 if a flow branch tests it. Embedded data fields,
randomiser assignments and `Displayed` conditions earn nothing.

**Reference-only entries.**
[`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
holds these Table 1 weights for completeness, and no automatic rule
reads them, so changing them leaves every score the same. They are
`rank_per_item`, `open_medium`, `please_specify` and
`open_essay_per_extra`. In practice:

- a ranking scores its first item only, so rankings of several items are
  under-scored;
- “please specify” boxes and repeated open answers score as the widget
  Qualtrics used for them (a text box).

Where your survey has these, check the affected questions’ `score_basis`
and adjust by hand if needed.

**What can make the reported figures too low.** Unscored (`unknown`)
questions contribute 0, loops without an explicit cap count once, and
the reference-only items above are under-scored.
[`burden_report()`](https://pmpk20.github.io/surveyBurden/reference/burden_report.md)
warns about unscored questions, and
[`calculation_certainty()`](https://pmpk20.github.io/surveyBurden/reference/calculation_certainty.md)
counts loops with unknown caps.

## Overriding the weights

You can change any weight in
[`gfs_scheme()`](https://pmpk20.github.io/surveyBurden/reference/gfs_scheme.md)
and pass the scheme back in. Only the entries a rule uses (table above)
affect scores.

``` r

w2 <- gfs_scheme()
w2$rating_small <- 2.5
score_burden(catalogue, scheme = w2)$gfs_points[1:5]
#> [1] 11.0  1.0  2.5  1.0  2.5
```

## Next

- [`vignette("paths-and-display-logic")`](https://pmpk20.github.io/surveyBurden/articles/paths-and-display-logic.md)
  shows how scores combine across paths.
- [`vignette("survey-revision")`](https://pmpk20.github.io/surveyBurden/articles/survey-revision.md)
  uses scores to revise a draft.
- [`vignette("calibration")`](https://pmpk20.github.io/surveyBurden/articles/calibration.md)
  converts points to minutes.

## References

- Heimgartner, D. and Axhausen, K. W. (2024). Predicting response rates
  once again. *Findings*. <https://doi.org/10.32866/001c.125481>
- Schmid, B. and Axhausen, K. W. (2019). Predicting response rates of
  all and recruited respondents: a first attempt. *Findings*.
  <https://doi.org/10.32866/7827>
- Yan, T. and Williams, D. (2022). Response burden: review and
  conceptual framework. *Journal of Official Statistics* 38(4), 939–961.
  <https://doi.org/10.2478/jos-2022-0041>
