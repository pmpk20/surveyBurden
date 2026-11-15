# Revising a survey to reduce burden

**What this answers.** Which part of a draft survey carries the most
burden, why it scores as it does, and how much a specific change reduces
the modelled burden.

**What you need.** The draft’s `.qsf` (export it from Qualtrics: *Tools
\> Import/Export \> Export survey*), and the revised version’s `.qsf`
after you edit it.

``` r

library(surveyBurden)
#> 
#>                   .-- Q2 -- Q3 --.
#>   survey -- Q1 --+               +-- Burden 0.3.0
#>                   '-- Q4 --------'
#> 
#> An R package for assessing the response-burden of web surveys
#> Docs: https://pmpk20.github.io/surveyBurden/
#> 
#> Please cite: King P (2026). surveyBurden: An R package for assessing
#> the response-burden of web surveys. R package version 0.3.0,
#> https://github.com/pmpk20/surveyBurden.
#> Use citation("surveyBurden") for BibTeX.
demo <- system.file("extdata", "demo_travel_survey.qsf", package = "surveyBurden")
before <- burden_report(demo, quiet = TRUE)
```

## 1. Find where the burden is

Start with blocks, then the questions inside the heaviest ones.

``` r

b <- before$blocks
b[order(-b$share), c("block_name", "n_questions", "gfs_points", "share")][1:3, ]
#> # A tibble: 3 × 4
#>   block_name n_questions gfs_points share
#>   <chr>            <int>      <dbl> <dbl>
#> 1 Travel               2         26 0.230
#> 2 Attitudes            1         18 0.159
#> 3 About you            5         15 0.133

it <- before$items
it[order(-it$gfs_points),
   c("question_id", "block_name", "std_type", "n_rows", "n_cols", "gfs_points")][1:4, ]
#> # A tibble: 4 × 6
#>   question_id block_name std_type     n_rows n_cols gfs_points
#>   <chr>       <chr>      <chr>         <int>  <int>      <dbl>
#> 1 QID21       Attitudes  matrix            6      7         18
#> 2 QID19       Travel     matrix            7      4         14
#> 3 QID14       Vehicles   multi_choice     NA     NA         12
#> 4 QID20       Travel     matrix            6      4         12
```

A block’s share counts the points of all its questions, including those
that only some paths show. `before$paths` shows which paths include
which blocks.

## 2. Check how the heavy questions were scored

Before changing a question, check how it was scored. The score should
reflect the question’s design, through a rule you accept.

``` r

it[it$question_id %in% c("QID21", "QID19"), c("question_id", "score_flag", "score_basis")]
#> # A tibble: 2 × 3
#>   question_id score_flag score_basis                                  
#>   <chr>       <chr>      <chr>                                        
#> 1 QID19       auto       matrix, 7 rows x GfS rating <=5 (2.0 per row)
#> 2 QID21       auto       matrix, 6 rows x GfS rating >5 (3.0 per row)
```

Both are `auto`. A single-answer matrix scores one rating per row, and a
rating with more than 5 options scores 3 points against 2 for up to 5
(see
[`vignette("gfs-scoring")`](https://pmpk20.github.io/surveyBurden/articles/gfs-scoring.md)).
So `QID21`, a 6-statement agreement grid on a 7-point scale, scores 6 x
3 = 18 points. The rule suggests two changes, fewer statements or a
5-point scale.

If a heavy question is `inferred`, read its `score_basis` first. Its
burden may come from a mapping rule (for example, a slider scored as a
numerical answer).

## 3. Make the change and re-score

Make the edit in Qualtrics and export the revised `.qsf`. To keep this
article self-contained, the same edit is made here in R. It keeps 4 of
the 6 statements and 5 of the 7 scale points.

``` r

revised <- read_qsf(demo)
i <- which(vapply(revised$SurveyElements, function(e)
  identical(e$Element, "SQ") && identical(e$Payload$QuestionID, "QID21"),
  logical(1)))
p <- revised$SurveyElements[[i]]$Payload
p$Choices <- p$Choices[1:4]   # statements (rows)
p$Answers <- p$Answers[1:5]   # scale points (columns)
revised$SurveyElements[[i]]$Payload <- p

after <- burden_report(revised, quiet = TRUE)
```

With a real revised export you would run
`after <- burden_report("my_survey_v2.qsf")`.

## 4. Compare

``` r

data.frame(
  statistic = before$burden$statistic,
  before    = before$burden$points,
  after     = after$burden$points,
  change    = after$burden$points - before$burden$points
)
#>   statistic before after change
#> 1       min    103    93    -10
#> 2       p25    114   104    -10
#> 3    median    120   110    -10
#> 4       p75    126   116    -10
#> 5       max    143   133    -10

q <- "QID21"
rbind(before = before$items[before$items$question_id == q, c("n_rows", "n_cols", "gfs_points")],
      after  = after$items[after$items$question_id == q, c("n_rows", "n_cols", "gfs_points")])
#> # A tibble: 2 × 3
#>   n_rows n_cols gfs_points
#> *  <int>  <int>      <dbl>
#> 1      6      7         18
#> 2      4      5          8
```

`QID21` falls from 18 to 8 points. It is shown on every path, so every
quantile falls by the same 10 points. A change to a question that only
some paths show would move the quantiles by different amounts. Compare
`before$paths` and `after$paths` to see which paths changed.

To see which change did the work, make one at a time. Cutting to 4 rows
at 7 points would give 4 x 3 = 12, and keeping 6 rows at 5 points would
give 6 x 2 = 12.

## What the comparison shows

The comparison shows how much the revision lowers objective burden under
the GfS+ scheme and the package’s model of the survey’s routing. It also
shows which questions and paths the change comes from.

Three further questions need their own evidence.

- **Completion time.** The points-to-minutes rate is a rule of thumb, so
  `change / 12` minutes is a rough guide.
  [`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md)
  checks it against observed times (see
  [`vignette("calibration")`](https://pmpk20.github.io/surveyBurden/articles/calibration.md)).
- **Respondent behaviour.** Changes in data quality, response rates or
  break-off need fieldwork data to measure.
- **Measurement.** Dropping statements or scale points changes what the
  question measures, and that is a measurement decision for you to make.

## Next

- After fielding the revision, compare respondent burden with
  [`respondent_burden()`](https://pmpk20.github.io/surveyBurden/reference/respondent_burden.md)
  ([`vignette("respondent-burden")`](https://pmpk20.github.io/surveyBurden/articles/respondent-burden.md)),
  and check predicted against observed completion times with
  [`validate_times()`](https://pmpk20.github.io/surveyBurden/reference/validate_times.md)
  ([`vignette("calibration")`](https://pmpk20.github.io/surveyBurden/articles/calibration.md)).
- [`vignette("gfs-scoring")`](https://pmpk20.github.io/surveyBurden/articles/gfs-scoring.md)
  lists the scoring rule for every question type.
