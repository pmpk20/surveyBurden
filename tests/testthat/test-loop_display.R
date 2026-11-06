# Display logic inside Loop & Merge blocks: the iteration-position gate,
# gate classification, and the loop-aware structural profile.

test_that("LoopAndMerge CurrentLoop literal becomes the @@iter gate", {
  p <- parse_display_logic(lp_pos_logic())
  expect_identical(p$vars, "@@iter")
  expect_true(p$predicate(list("@@iter" = 1L)))
  expect_false(p$predicate(list("@@iter" = 2L)))
  # outside a loop Qualtrics leaves lm://CurrentLoop empty: never shown
  expect_false(p$predicate(list()))
  # the literal reads "Loop k <op> Current Loop": op(k, current)
  expect_true(parse_display_logic(lp_pos_logic(op = "LessThan"))$predicate(list("@@iter" = 3L)))
  expect_false(parse_display_logic(lp_pos_logic(op = "GreaterThan"))$predicate(list("@@iter" = 3L)))
  expect_identical(parse_display_logic(lp_pos_logic(block = "BL_q"))$loop_blocks, "BL_q")
})

test_that("loop gates split into iteration, shared and position", {
  parsed <- list(
    QIDb = parse_display_logic(fg_logic(list(LogicType = "Question",
      QuestionID = "QIDa", QuestionIsInLoop = "no", ChoiceLocator = "q://QIDa/SelectableChoice/1",
      Operator = "Selected", LeftOperand = "q://QIDa/SelectableChoice/1", Type = "Expression"))),
    QIDc = parse_display_logic(fg_logic(fg_emb("hh", "EqualTo", "1"))),
    QIDd = parse_display_logic(lp_pos_logic("BL_L")))
  qblock <- c(QIDa = "BL_L", QIDb = "BL_L", QIDc = "BL_L", QIDd = "BL_L", QIDz = "BL_main")
  g <- classify_loop_gates(c("QIDb", "QIDc", "QIDd"), "BL_L", parsed, qblock)
  expect_identical(g$iter, "QIDa")
  expect_identical(g$shared, "@hh")
  expect_true(g$position)
  expect_false(classify_loop_gates("QIDc", "BL_L", parsed, qblock)$position)
})

test_that("item_flags marks visible and responsive items as respondent_burden() does", {
  sc <- tibble::tibble(question_id = c("Q1", "Q2", "Q3", "Q4"),
                       qualtrics_type = c("MC", "DB", "Timing", "MC"),
                       is_hidden = c(FALSE, FALSE, FALSE, TRUE))
  f <- item_flags(sc)
  expect_identical(unname(f$visible), c(TRUE, TRUE, FALSE, FALSE))
  expect_identical(unname(f$responsive), c(TRUE, FALSE, FALSE, TRUE))
  expect_identical(names(f$visible), sc$question_id)
})

test_that("force_response_map reads only ForceResponse ON", {
  mk <- function(qid, fr) { p <- fg_mc(qid, 2)
    if (!is.null(fr)) p$Validation <- list(Settings = list(ForceResponse = fr)); p }
  q <- as_qsf_raw(list(SurveyEntry = list(SurveyID = "SV", SurveyName = "x"),
    SurveyElements = lapply(list(mk("Q1", "ON"), mk("Q2", "RequestResponse"), mk("Q3", "OFF"), mk("Q4", NULL)),
      function(p) list(Element = "SQ", PrimaryAttribute = p$QuestionID, SecondaryAttribute = "", Payload = p))))
  expect_identical(force_response_map(q), c(Q1 = TRUE, Q2 = FALSE, Q3 = FALSE, Q4 = FALSE))
})

# ---- loop-aware structural profile -------------------------------------------

test_that("shared gate holds one state across iterations", {
  # QIDh 1 pt; loop (max 2) QIDb 2 pts shown when QIDh = 1
  q <- lp_qsf(list(list(id = "BL_M", qs = list(fg_mc("QIDh", 2))),
                   list(id = "BL_L", loop = 2, qs = list(fg_mc("QIDb", 3, fg_logic(lp_sel("QIDh", 1)))))))
  lp_expect(lp_dist(q), c(`1` = .5, `3` = .25, `5` = .25))
})

test_that("iteration gate varies independently across iterations", {
  # loop (max 2): QIDa 1 pt always; QIDb 2 pts when this iteration's QIDa = 1
  q <- lp_qsf(list(list(id = "BL_L", loop = 2, qs = list(
    fg_mc("QIDa", 2), fg_mc("QIDb", 3, fg_logic(lp_sel("QIDa", 1)))))))
  lp_expect(lp_dist(q), c(`1` = .25, `3` = .25, `2` = .125, `4` = .25, `6` = .125))
})

test_that("n = 1 vs n = 2 totals follow loop_weights", {
  q <- lp_qsf(list(list(id = "BL_L", loop = 2, qs = list(
    fg_mc("QIDa", 2), fg_mc("QIDb", 3, fg_logic(lp_sel("QIDa", 1)))))))
  lp_expect(lp_dist(q, loop_weights = list(BL_L = c(1, 0))), c(`1` = .5, `3` = .5))
  lp_expect(lp_dist(q, loop_weights = list(BL_L = c(0, 1))), c(`2` = .25, `4` = .5, `6` = .25))
  lp_expect(lp_dist(q, loop_weights = list(BL_L = function(state) c(0, 3))),
            c(`2` = .25, `4` = .5, `6` = .25))
})

test_that("position question counted once", {
  q <- lp_qsf(list(list(id = "BL_L", loop = 3, qs = list(fg_mc("QIDp", 3, lp_pos_logic("BL_L", 1))))))
  lp_expect(lp_dist(q, loop_weights = list(BL_L = c(0, 0, 1))), c(`2` = 1))
  lp_expect(lp_dist(q), c(`2` = 1))
})

test_that("shared gate couples loop and non-loop questions", {
  # QIDh 1 pt; QIDm 3 pts and loop QIDb 2 pts both shown when QIDh = 1
  q <- lp_qsf(list(list(id = "BL_M", qs = list(fg_mc("QIDh", 2), fg_mc("QIDm", 7, fg_logic(lp_sel("QIDh", 1))))),
                   list(id = "BL_L", loop = 1, qs = list(fg_mc("QIDb", 3, fg_logic(lp_sel("QIDh", 1)))))))
  lp_expect(lp_dist(q), c(`1` = .5, `6` = .5))
})

test_that("cross-loop trigger is shared and flagged", {
  q <- lp_qsf(list(list(id = "BL_A", loop = 2, qs = list(fg_mc("QIDa", 2))),
                   list(id = "BL_B", loop = 2, qs = list(fg_mc("QIDb", 3, fg_logic(lp_sel("QIDa", 1)))))))
  e <- suppressMessages(suppressWarnings(burden_engine(q)))
  expect_true(any(e$unresolved$question_id == "QIDb" &
                    e$unresolved$reason == "trigger in another loop"))
})

test_that("nested gate: B never shown when A is hidden", {
  # X 1 pt always; A 1 pt when X = 1; B 3 pts when A = 1
  q <- lp_qsf(list(list(id = "BL_M", qs = list(
    fg_mc("QIDx", 2), fg_mc("QIDa", 2, fg_logic(lp_sel("QIDx", 1))),
    fg_mc("QIDb", 7, fg_logic(lp_sel("QIDa", 1)))))))
  lp_expect(lp_dist(q, respect_force_response = FALSE), c(`1` = .5, `2` = .25, `5` = .25))
})

test_that("forced-response trigger has no unanswered state", {
  # T (2 choices, 1 pt): Q2 (2 pts) when T = 1, Q3 (3 pts) when T = 2
  mk <- function(t) lp_qsf(list(list(id = "BL_M", qs = list(
    t, fg_mc("QID2", 3, fg_logic(lp_sel("QIDt", 1))), fg_mc("QID3", 7, fg_logic(lp_sel("QIDt", 2)))))))
  forced <- mk(lp_forced(fg_mc("QIDt", 2)))
  lp_expect(lp_dist(forced), c(`3` = .5, `4` = .5))
  lp_expect(lp_dist(forced, respect_force_response = FALSE), c(`1` = 1/3, `3` = 1/3, `4` = 1/3))
  lp_expect(lp_dist(mk(lp_forced(fg_mc("QIDt", 2), "RequestResponse"))),
            c(`1` = 1/3, `3` = 1/3, `4` = 1/3))
  # three choices, two referenced: "none" (answered choice 3) stays
  three <- mk(lp_forced(fg_mc("QIDt", 3)))
  lp_expect(lp_dist(three), c(`2` = 1/3, `4` = 1/3, `5` = 1/3))
})

test_that("bad loop_weights error clearly", {
  q <- lp_qsf(list(list(id = "BL_L", loop = 2, qs = list(fg_mc("QIDa", 2)))))
  pb <- function(w) suppressMessages(path_burden_profile(q, loop_weights = w))
  expect_error(pb(list(BL_L = c(1, 1, 1))), "BL_L")
  expect_error(pb(list(BL_L = c(1, -1))), "BL_L")
  expect_error(pb(list(BL_L = c(0, 0))), "BL_L")
  expect_error(pb(list(BL_nope = c(1, 1))), "BL_nope")
})

test_that("surveys without loop display logic are unchanged", {
  snap <- readRDS(test_path("fixtures", "profile_pre_loop.rds"))
  for (n in c("demo_simple_linear", "demo_display_logic", "demo_large_branching")) {
    q <- read_qsf(system.file("extdata", paste0(n, ".qsf"), package = "surveyBurden"))
    got <- suppressMessages(path_burden_profile(q))
    expect_equal(nrow(attr(got, "approximations")), 0L, label = n)
    attr(got, "unresolved") <- NULL; attr(got, "approximations") <- NULL
    expect_identical(got, snap[[n]], label = n)
  }
})

test_that("burden_report() and calculation_certainty() pass the loop arguments on", {
  q <- lp_qsf(list(list(id = "BL_L", loop = 2, qs = list(
    fg_mc("QIDa", 2), fg_mc("QIDb", 3, fg_logic(lp_sel("QIDa", 1)))))))
  r <- burden_report(q, quiet = TRUE, loop_weights = list(BL_L = c(0, 1)))
  expect_equal(r$burden$points[c(1, 5)], c(2, 6))
  cc <- calculation_certainty(q, loop_weights = list(BL_L = c(0, 1)),
                              respect_force_response = FALSE)
  expect_true(is.list(cc))
  expect_error(burden_report(q, quiet = TRUE, loop_weights = list(BL_L = 1)), "BL_L")
})

# ---- final-review fixes ------------------------------------------------------

lp_notsel <- function(qid, choice) { x <- lp_sel(qid, choice); x$Operator <- "NotSelected"; x }

test_that("C1: function loop weights on a loop without display logic", {
  q <- lp_qsf(list(list(id = "BL_L", loop = 2, qs = list(fg_mc("QIDa", 2)))))
  lp_expect(lp_dist(q, loop_weights = list(BL_L = function(s) c(1, 3))), c(`1` = .25, `2` = .75))
})

test_that("I1: hidden triggers settle in dependency order, whatever the catalogue order", {
  # X always; B if X = 1; A if B NotSelected 1; C (3 pts) if A = 1. C listed before A.
  q <- lp_qsf(list(list(id = "BL_M", qs = list(
    fg_mc("QIDx", 2), fg_mc("QIDc", 7, fg_logic(lp_sel("QIDa", 1))),
    fg_mc("QIDb", 2, fg_logic(lp_sel("QIDx", 1))), fg_mc("QIDa", 2, fg_logic(lp_notsel("QIDb", 1)))))))
  lp_expect(lp_dist(q, respect_force_response = FALSE),
            c(`2` = .5, `3` = .125, `5` = .25, `6` = .125))
})

test_that("I2: many independent iteration triggers stay exact (no silent permissive cap)", {
  # loop (max 2): 14 independent pairs, trigger (1 pt) -> dependant (2 pts) on choice 1
  qs <- unlist(lapply(seq_len(14), function(i) {
    t <- sprintf("QIDt%02d", i)
    list(fg_mc(t, 2), fg_mc(sprintf("QIDd%02d", i), 3, fg_logic(lp_sel(t, 1))))
  }), recursive = FALSE)
  q <- lp_qsf(list(list(id = "BL_L", loop = 2, qs = qs)))
  d <- lp_dist(q)
  mean_b <- sum(as.numeric(names(d)) * d)
  # per iteration: 14 + 14 * 2 * 0.5 = 28 points; uniform n in {1, 2} -> 1.5 iterations
  expect_equal(mean_b, 42, tolerance = 1e-9)
})

test_that("M2: a loop trigger the route never shows does not show its dependants", {
  # In the loop, QIDa needs QIDzz (in a block outside the flow), so it is never
  # shown; QIDb (2 pts) shows if this iteration's QIDa = 1 OR QIDh = 1 (QIDh 1 pt)
  q <- lp_qsf(list(list(id = "BL_M", qs = list(fg_mc("QIDh", 2))),
                   list(id = "BL_L", loop = 1, qs = list(
                     fg_mc("QIDa", 2, fg_logic(lp_sel("QIDzz", 1))),
                     fg_mc("QIDb", 3, fg_logic(lp_sel("QIDa", 1), lp_sel("QIDh", 1, conj = "Or")))))))
  q <- lp_add_unflowed_block(q, "BL_S", fg_mc("QIDzz", 2))
  lp_expect(lp_dist(q), c(`1` = .5, `3` = .5))
})

test_that("profile lists its approximations for the caller", {
  qs <- unlist(lapply(seq_len(3), function(i) {
    t <- sprintf("QIDt%02d", i)
    list(fg_mc(t, 2), fg_mc(sprintf("QIDd%02d", i), 3, fg_logic(lp_sel(t, 1))))
  }), recursive = FALSE)
  q <- lp_qsf(list(list(id = "BL_L", loop = 2, qs = qs)))
  ok <- suppressMessages(path_burden_profile(q))
  expect_equal(nrow(attr(ok, "approximations")), 0L)
  capped <- suppressMessages(path_burden_profile(q, max_condition_states = 1))
  a <- attr(capped, "approximations")
  expect_true(nrow(a) > 0)
  expect_true(all(c("path_id", "question_id", "reason") %in% names(a)))
})
