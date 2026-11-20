# Public answer_weights behaviour, with burdens and probabilities worked by hand.
aw_run <- function(...) suppressMessages(suppressWarnings(path_burden_traversals(...)))
aw_fixture <- function() lp_qsf(list(list(id = "BL_A", qs = list(
  fg_mc("QID1", 2),
  fg_mc("QID2", 2, fg_logic(lp_sel("QID1", 1))),
  fg_mc("QID3", 2, fg_logic(lp_sel("QID1", 2)))
))))
aw_scores <- c(QID1 = 1, QID2 = 10, QID3 = 20)
aw_distribution <- function(x) {
  d <- stats::aggregate(weight ~ points, as.data.frame(x), sum)
  stats::setNames(d$weight, d$points)
}
aw_flow_fixture <- function(end_early = FALSE) {
  q <- lp_qsf(list(
    list(id = "BL_Start", qs = list(fg_mc("QID1", 2))),
    list(id = "BL_Yes", qs = list(fg_mc("QID2", 2, fg_logic(lp_sel("QID1", 1)))))
  ))
  branch <- list(Type = "Branch", FlowID = "FL_Branch",
    BranchLogic = fg_logic(lp_sel("QID1", 1)),
    Flow = if (end_early) list(list(Type = "EndSurvey", FlowID = "FL_End")) else
      list(list(Type = "Standard", ID = "BL_Yes", FlowID = "FL_Yes")))
  q$SurveyElements <- lapply(q$SurveyElements, function(e) {
    if (identical(e$Element, "FL")) {
      e$Payload$Flow <- list(list(Type = "Standard", ID = "BL_Start", FlowID = "FL_Start"), branch)
      if (end_early) e$Payload$Flow <- c(e$Payload$Flow,
        list(list(Type = "Standard", ID = "BL_Yes", FlowID = "FL_Yes")))
    }
    e
  })
  q
}

test_that("NULL and empty answer weights preserve output and random state", {
  q <- aw_fixture()
  for (method in c("exact", "sample")) {
    set.seed(123)
    previous <- .Random.seed
    plain <- aw_run(q, method = method, n_draws = 100, output = "wide")
    expect_identical(.Random.seed, previous)
    expect_identical(aw_run(q, method = method, n_draws = 100,
                            answer_weights = NULL, output = "wide"), plain)
    expect_identical(aw_run(q, method = method, n_draws = 100,
                            answer_weights = list(), output = "wide"), plain)
    expect_identical(.Random.seed, previous)
  }
})

test_that("answer frequencies give hand-computed masses and quantiles", {
  q <- aw_fixture()
  x <- aw_run(q, method = "exact", overrides = aw_scores, output = "wide",
              answer_weights = list(QID1 = c(`1` = 2, `2` = 8)))
  expect_equal(aw_distribution(x), c(`11` = .2, `21` = .8))
  expect_equal(weighted_quantile(x$points, x$weight, c(0, .1, .25, .5, .75, 1)),
               c(11, 11, 21, 21, 21, 21))
  expect_match(attr(x, "convention"), "under assumed answer frequencies")
  sampled <- aw_run(q, method = "sample", n_draws = 10000, seed = 42,
    overrides = aw_scores, output = "wide",
    answer_weights = list(QID1 = c(`1` = 2, `2` = 8)))
  expect_equal(sum(sampled$weight[sampled$points == 11]), .2, tolerance = .02)
  expect_equal(weighted_quantile(sampled$points, sampled$weight, c(.25, .5, .75)),
               c(21, 21, 21))
})

test_that("equal state frequencies reproduce the unweighted distribution", {
  q <- aw_fixture()
  plain <- aw_run(q, method = "exact", overrides = aw_scores, output = "wide")
  equal <- aw_run(q, method = "exact", overrides = aw_scores, output = "wide",
    answer_weights = list(QID1 = stats::setNames(rep(1, 3), c("1", "2", ""))))
  expect_equal(aw_distribution(equal), aw_distribution(plain))
})

test_that("a fixed answer agrees with the field-rule rejection workaround", {
  q <- aw_fixture()
  fixed <- aw_run(q, method = "exact", overrides = aw_scores, output = "wide",
                  answer_weights = list(QID1 = c(`1` = 1)))
  rejected <- aw_run(q, method = "exact", overrides = aw_scores, output = "wide",
    field_rules = list(`@accept` = list(inputs = "QID1", fun = function(s) {
      if (identical(s[["QID1"]], "1")) 1 else NA
    })))
  expect_equal(aw_distribution(fixed), aw_distribution(rejected))
})

test_that("multi-answer weights describe joint subsets within a question", {
  q <- aw_fixture()
  q$SurveyElements <- lapply(q$SurveyElements, function(e) {
    if (identical(e$PrimaryAttribute, "QID1")) e$Payload$Selector <- "MAVR"
    e
  })
  x <- aw_run(q, method = "exact", overrides = aw_scores, output = "wide",
    answer_weights = list(QID1 = stats::setNames(c(1, 2, 3, 4), c("", "1", "2", "1+2"))))
  expect_equal(aw_distribution(x), c(`1` = .1, `11` = .2, `21` = .3, `31` = .4))
  expect_equal(sum(x$weight), 1)
  expect_error(aw_run(q, answer_weights = list(QID1 = c(`1+2` = 1, `2+1` = 1))),
               "answer_weights")
})

test_that("hidden forced triggers do not enforce their assumed answer", {
  q <- lp_qsf(list(list(id = "BL_A", qs = list(
    fg_mc("QID1", 2),
    lp_forced(fg_mc("QID2", 2, fg_logic(lp_sel("QID1", 1)))),
    fg_mc("QID3", 2, fg_logic(lp_sel("QID2", 1)))
  ))))
  x <- aw_run(q, method = "exact", overrides = aw_scores, output = "wide",
    answer_weights = list(QID1 = c(`1` = .25, `2` = .75), QID2 = c(`1` = 1)))
  expect_equal(aw_distribution(x), c(`1` = .75, `31` = .25))
})

test_that("raw stored-field values combine probability within threshold classes", {
  q <- lp_qsf(list(list(id = "BL_A", qs = list(
    fg_mc("QID1", 2),
    fg_mc("QID2", 2, fg_logic(fg_emb("cars", "GreaterThan", "1"))),
    fg_mc("QID3", 2, fg_logic(fg_emb("cars", "GreaterThan", "5")))
  ))))
  x <- aw_run(q, method = "exact", overrides = aw_scores, output = "wide",
    answer_weights = list(`@cars` = c(`0` = 2, `2` = 1, `3` = 2, `8` = 5)))
  expect_equal(aw_distribution(x), c(`1` = .2, `11` = .3, `31` = .5))
})

test_that("invalid answer weights fail before traversal", {
  q <- aw_fixture()
  bad <- list(
    list(QID1 = c(`1` = 0, `2` = 0)),
    list(QID1 = c(`1` = -1, `2` = 2)),
    list(QID1 = c(`1` = Inf)),
    list(QID1 = c(`1` = NA_real_)),
    list(QID1 = c(`1` = NaN)),
    list(QID1 = c(1, 2)),
    list(QID1 = stats::setNames(c(1, 2), c("1", "1"))),
    list(QID1 = c(`99` = 1)),
    list(QID1 = c(`1+2` = 1)),
    list(QID999 = c(`1` = 1)),
    list(`@unknown` = c(`1` = 1)),
    list(c(`1` = 1)),
    stats::setNames(list(c(`1` = 1), c(`2` = 1)), c("QID1", "QID1")),
    data.frame(QID1 = "1", weight = 1)
  )
  for (weights in bad) {
    expect_error(aw_run(q, method = "exact", answer_weights = weights), "answer_weights")
  }
})

test_that("forced-response and field-domain assumptions are explicit", {
  forced <- lp_qsf(list(list(id = "BL_A", qs = list(
    lp_forced(fg_mc("QID1", 2)),
    fg_mc("QID2", 2, fg_logic(lp_sel("QID1", 1)))
  ))))
  unanswered <- list(QID1 = stats::setNames(1, ""))
  expect_error(aw_run(forced, answer_weights = unanswered), "answer_weights")
  x <- aw_run(forced, method = "exact", answer_weights = unanswered,
              respect_force_response = FALSE, overrides = c(QID1 = 1, QID2 = 10),
              output = "wide")
  expect_equal(aw_distribution(x), c(`1` = 1))

  field <- lp_qsf(list(list(id = "BL_A", qs = list(
    fg_mc("QID1", 2, fg_logic(fg_emb("cars", "GreaterThan", "1")))
  ))))
  expect_error(aw_run(field, field_domains = list(cars = c(0, 1)),
    answer_weights = list(`@cars` = c(`2` = 1))), "answer_weights")
  expect_error(aw_run(field, field_rules = list(`@cars` = function(s) 2),
    answer_weights = list(`@cars` = c(`2` = 1))), "answer_weights")
})

test_that("finite large weights are normalised without overflow", {
  x <- aw_run(aw_fixture(), method = "exact", overrides = aw_scores, output = "wide",
    answer_weights = list(QID1 = c(`1` = 1e308, `2` = 1e308)))
  expect_equal(aw_distribution(x), c(`11` = .5, `21` = .5))
})

test_that("the same answer controls flow and display without a second draw", {
  q <- aw_flow_fixture()
  x <- aw_run(q, method = "exact", overrides = c(QID1 = 1, QID2 = 10),
    answer_weights = list(QID1 = c(`1` = .8, `2` = .2)), output = "wide")
  expect_equal(aw_distribution(x), c(`1` = .2, `11` = .8))
  fixed <- aw_run(q, method = "exact", overrides = c(QID1 = 1, QID2 = 10),
    answer_weights = list(QID1 = c(`1` = 1, `2` = 0)), output = "wide")
  expect_equal(aw_distribution(fixed), c(`11` = 1))
  expect_length(unique(fixed$path_id), 1L)
})

test_that("complete-only output conditions on positive completion probability", {
  q <- aw_flow_fixture(end_early = TRUE)
  x <- aw_run(q, method = "exact", overrides = c(QID1 = 1, QID2 = 10),
    answer_weights = list(QID1 = c(`1` = .8, `2` = .2)), output = "wide")
  expect_equal(aw_distribution(x), c(`1` = 1))
  expect_error(aw_run(q, method = "exact",
    answer_weights = list(QID1 = c(`1` = 1))), "positive.*answer_weights|answer_weights.*positive")
  both <- aw_run(q, method = "exact", complete_only = FALSE,
    answer_weights = list(QID1 = c(`1` = .8, `2` = .2)), output = "wide")
  expect_equal(sum(both$weight), 1)
  expect_length(unique(both$path_id), 2L)
})

test_that("answer and loop-count weights combine across fresh iteration answers", {
  q <- lp_qsf(list(list(id = "BL_L", loop = 2, qs = list(
    lp_forced(fg_mc("QID1", 2)),
    fg_mc("QID2", 2, fg_logic(lp_sel("QID1", 1)))
  ))))
  arguments <- list(qsf = q, overrides = c(QID1 = 1, QID2 = 10),
    answer_weights = list(QID1 = c(`1` = .25, `2` = .75)),
    loop_weights = list(BL_L = c(.2, .8)), output = "wide")
  exact <- do.call(aw_run, c(arguments, list(method = "exact")))
  expect_equal(aw_distribution(exact), c(`1` = .15, `2` = .45, `11` = .05,
                                       `12` = .3, `22` = .05))
  sampled <- do.call(aw_run, c(arguments, list(method = "sample", n_draws = 12000, seed = 44)))
  expect_equal(aw_distribution(sampled), aw_distribution(exact), tolerance = .02)
  expect_equal(weighted_quantile(sampled$points, sampled$weight, c(.25, .5, .75)),
               c(2, 2, 12))
})

test_that("explicit multi-answer subsets retain a seventh referenced choice", {
  trigger <- fg_mc("QID1", 7)
  trigger$Selector <- "MAVR"
  children <- lapply(1:7, function(i) {
    fg_mc(paste0("QID", i + 1L), 2, fg_logic(lp_sel("QID1", i)))
  })
  q <- lp_qsf(list(list(id = "BL_A", qs = c(list(trigger), children))))
  x <- aw_run(q, method = "exact", output = "wide",
    overrides = stats::setNames(c(1, 1:7), paste0("QID", 1:8)),
    answer_weights = list(QID1 = stats::setNames(c(.9, .1), c("", "7"))))
  expect_equal(aw_distribution(x), c(`1` = .9, `8` = .1))
})

test_that("empty stored values map to missing and literal boolean values stay raw", {
  numeric_field <- lp_qsf(list(list(id = "BL_A", qs = list(
    fg_mc("QID1", 2),
    fg_mc("QID2", 2, fg_logic(fg_emb("cars", "GreaterThan", "1")))
  ))))
  x <- aw_run(numeric_field, method = "exact", output = "wide",
    overrides = c(QID1 = 1, QID2 = 10),
    answer_weights = list(`@cars` = stats::setNames(c(.4, .6), c("", "2"))))
  expect_equal(aw_distribution(x), c(`1` = .4, `11` = .6))

  boolean_field <- lp_qsf(list(list(id = "BL_A", qs = list(
    fg_mc("QID1", 2),
    fg_mc("QID2", 2, fg_logic(fg_emb("flag", "EqualTo", "TRUE")))
  ))))
  y <- aw_run(boolean_field, method = "exact", output = "wide",
    overrides = c(QID1 = 1, QID2 = 10),
    answer_weights = list(`@flag` = c(`TRUE` = .3, `FALSE` = .7)))
  expect_equal(aw_distribution(y), c(`1` = .7, `11` = .3))
})

test_that("numeric question aliases evaluate raw entries rather than boolean states", {
  literal <- list(LogicType = "Question", QuestionID = "QID1",
    LeftOperand = "q://QID1/ChoiceNumericEntryValue/1",
    Operator = "NotEqualTo", RightOperand = "0")
  q <- lp_qsf(list(list(id = "BL_A", qs = list(
    fg_mc("QID1", 2), fg_mc("QID2", 2, fg_logic(literal))
  ))))
  alias <- "@q://QID1/ChoiceNumericEntryValue/1"
  x <- aw_run(q, method = "exact", output = "wide",
    overrides = c(QID1 = 1, QID2 = 10),
    answer_weights = stats::setNames(list(c(`0` = .4, `3` = .6)), alias))
  expect_equal(aw_distribution(x), c(`1` = .4, `11` = .6))
  y <- aw_run(q, method = "exact", output = "wide",
    overrides = c(QID1 = 1, QID2 = 10),
    answer_weights = stats::setNames(list(c(`TRUE` = .3, `FALSE` = .7)), alias))
  expect_equal(aw_distribution(y), c(`11` = 1))
})

test_that("numeric-entry aliases evaluate raw TRUE and FALSE as values", {
  literal <- list(LogicType = "Question", QuestionID = "QID1",
    LeftOperand = "q://QID1/ChoiceNumericEntryValue/1", Operator = "GreaterThan",
    RightOperand = "1", Type = "Expression")
  entry <- fg_mc("QID1", 2)
  entry$QuestionType <- "TE"
  entry$Selector <- "SL"
  q <- lp_qsf(list(list(id = "BL_A", qs = list(entry,
    fg_mc("QID2", 2, fg_logic(literal))))))
  # Neither string is a number greater than 1; they are not truth outcomes.
  x <- aw_run(q, method = "exact", output = "wide",
    overrides = c(QID1 = 1, QID2 = 10),
    answer_weights = list(`@q://QID1/ChoiceNumericEntryValue/1` = c(`TRUE` = .3, `FALSE` = .7)))
  expect_equal(aw_distribution(x), c(`1` = 1))
})
