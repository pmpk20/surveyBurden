# Display logic inside Loop & Merge blocks: the iteration-position gate,
# gate classification, and the loop-aware structural profile.

lp_pos_logic <- function(block = "BL_x", k = 1, op = "EqualTo") {
  list(`0` = list(`0` = list(LogicType = "LoopAndMerge",
                             LeftOperand = paste0(block, ",", k), Operator = op,
                             RightOperand = "lm://CurrentLoop", Type = "Expression"),
                  Type = "If"),
       Type = "BooleanExpression", inPage = FALSE)
}

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
