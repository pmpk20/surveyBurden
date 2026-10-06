# rb_blocks() edge cases, each built by editing the synthetic fixture
# survey (fixtures/exposure_fixture.qsf) in memory. Helpers for the fixture
# and its responses are defined here.

exposure_qsf <- function() test_path("fixtures", "exposure_fixture.qsf")

exposure_responses <- function() {
  data.frame(
    ResponseId = paste0("R", 1:5),
    Finished   = c(1, 1, 0, 0, 1),
    Mode       = c("web", "web", "phone", "web", "phone"),
    QID1       = c("1", "2", "1", "1", "1"),
    QID2       = c("2", NA, "3", "0", "1"),
    QID3_1     = c("1", NA, NA, NA, "1"),
    QID3_2     = c(NA, NA, "1", NA, NA),
    QID4       = c("1", NA, NA, NA, "2"),
    `1_QID5`   = c("1", NA, "2", NA, "3"),
    `1_QID6`   = c("2", NA, NA, NA, "1"),
    `1_QID7`   = c("1", NA, "1", NA, "1"),
    `2_QID5`   = c("2", NA, "1", NA, NA),
    QID8       = c("friend", NA, NA, NA, NA),
    QID9       = c("2", NA, NA, NA, NA),
    QID10      = c(NA, NA, NA, NA, "1"),
    QID12      = c(NA, NA, NA, NA, "2"),
    QID13      = c("1", NA, NA, NA, "3"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

cell <- function(ex, rid, bid, col) ex[[col]][ex$response_id == rid & ex$block_id == bid]

fx_raw <- function() read_qsf(exposure_qsf())
fx_el <- function(q, type) {
  which(vapply(q$SurveyElements, function(e) identical(e$Element, type), TRUE))
}
fx_flow <- function(q) q$SurveyElements[[fx_el(q, "FL")]]$Payload$Flow
fx_with_flow <- function(q, flow) {
  q$SurveyElements[[fx_el(q, "FL")]]$Payload$Flow <- flow
  q
}
fx_block <- function(q, bid) {
  bl <- q$SurveyElements[[fx_el(q, "BL")]]$Payload
  bl[[which(vapply(bl, function(b) identical(b$ID, bid), TRUE))]]
}
fx_set_block <- function(q, bid, field, value) {
  i <- fx_el(q, "BL")
  bl <- q$SurveyElements[[i]]$Payload
  j <- which(vapply(bl, function(b) identical(b$ID, bid), TRUE))
  q$SurveyElements[[i]]$Payload[[j]][[field]] <- value
  q
}
fx_set_q <- function(q, qid, field, value) {
  i <- which(vapply(q$SurveyElements, function(e)
    identical(e$Element, "SQ") && identical(e$Payload$QuestionID, qid), TRUE))
  q$SurveyElements[[i]]$Payload[[field]] <- value
  q
}
run_q <- function(q, responses = exposure_responses(), ...) {
  suppressMessages(suppressWarnings(rb_blocks(q, responses, ...)))
}
sel <- function(qid, choice, op = "Selected") {
  list(LogicType = "Question", QuestionID = qid, Operator = op,
       LeftOperand = sprintf("q://%s/SelectableChoice/%s", qid, choice),
       Type = "Expression")
}
one_logic <- function(lit) {
  list(`0` = list(`0` = lit, Type = "If"), Type = "BooleanExpression")
}

test_that("an EndSurvey evaluated past a break-off's exit does not make a screen-out", {
  q <- fx_raw()
  # after Household: end the survey unless the respondent drives (QID4 = 1)
  gate <- list(Type = "Branch", FlowID = "FL_b_nodrive",
               BranchLogic = one_logic(sel("QID4", "1", "NotSelected")),
               Flow = list(list(Type = "EndSurvey", FlowID = "FL_end_nodrive")))
  q <- fx_with_flow(q, append(fx_flow(q), list(gate), after = 4L))
  r <- exposure_responses()
  r$`1_QID5`[5] <- NA; r$`1_QID6`[5] <- NA; r$`1_QID7`[5] <- NA
  r$QID10[5] <- NA; r$QID12[5] <- NA; r$QID13[5] <- NA
  ex <- run_q(q, r)
  # R4 left in Household without answering QID4: still a break-off
  expect_equal(cell(ex, "R4", "BL2", "outcome"), "breakoff")
  expect_true(cell(ex, "R4", "BL2", "exit_block"))
  expect_true(is.na(cell(ex, "R4", "BL3", "routed_in")))
  # R5 finished, does not drive, answered nothing later: screened out
  expect_equal(cell(ex, "R5", "BL2", "outcome"), "screen_out")
  expect_false(cell(ex, "R5", "BL3", "routed_in"))
})

test_that("an embedded field set twice in the flow is read as it was at each branch", {
  q <- fx_raw()
  fl <- fx_flow(q)
  fl[[1]]$EmbeddedData[[2]]$Value <- "1"            # Wave = 1 at the start
  later <- list(Type = "EmbeddedData", FlowID = "FL_ed2", EmbeddedData = list(
    list(Description = "Wave", Type = "Custom", Field = "Wave", Value = "2")))
  q <- fx_with_flow(q, append(fl, list(later), after = 7L))  # after the wave branch
  r <- exposure_responses()
  r$Wave <- "2"                                       # the export holds the final value
  r$QID9 <- NA; r$QID10 <- NA                         # no answers in Driving
  ex <- run_q(q, r)
  expect_false(cell(ex, "R1", "BL5", "routed_in"))
  expect_false(cell(ex, "R5", "BL5", "routed_in"))
})

test_that("flow assignments to an exported field apply in flow order", {
  mode_node <- function(type, value) list(Type = "EmbeddedData", FlowID = "FL_mode",
    EmbeddedData = list(list(Description = "Mode", Type = type, Field = "Mode",
                             Value = value)))
  with_modes <- function(...) {
    q <- fx_raw()
    fx_with_flow(q, append(fx_flow(q), list(...), after = 1L))
  }
  r <- exposure_responses()
  r$QID8 <- NA                                         # no answers behind the web gate
  # fixed "phone" then a computed value: back to the exported value (web)
  ex <- run_q(with_modes(mode_node("Custom", "phone"),
                         mode_node("Custom", "$e{ q://QID1/SelectedChoicesRecode + 1 }")), r)
  expect_true(cell(ex, "R1", "BL4", "routed_in"))
  # fixed "phone" alone: R1 is not routed into Web extras
  ex <- run_q(with_modes(mode_node("Custom", "phone")), r)
  expect_false(cell(ex, "R1", "BL4", "routed_in"))
  # an explicit empty value clears it: not "web" either
  ex <- run_q(with_modes(mode_node("Custom", "")), r)
  expect_false(cell(ex, "R1", "BL4", "routed_in"))
  # a bare declaration (set from a panel or URL) leaves the export value
  ex <- run_q(with_modes(mode_node("Recipient", "")), r)
  expect_true(cell(ex, "R1", "BL4", "routed_in"))
})

test_that("Displayed() inside a loop sees the earlier question in the same pass", {
  q <- fx_set_q(fx_raw(), "QID6", "DisplayLogic", one_logic(list(
    LogicType = "Question", QuestionID = "QID5", Operator = "Displayed",
    LeftOperand = "q://QID5/QuestionDisplayed", Type = "Expression")))
  ex <- run_q(q)
  # QID6 now shows whenever QID5 does: iteration 1 = 2 + 2 + 1, iteration 2 = 2 + 2
  expect_equal(cell(ex, "R1", "BL3", "points"), 9)
  expect_equal(cell(ex, "R1", "BL3", "unresolved_items"), 0L)
})

test_that("choice-driven loops map export iterations to choice positions", {
  q <- fx_set_q(fx_raw(), "QID3", "Choices", list(
    `1` = list(Display = "A car"), `4` = list(Display = "A bicycle"),
    `7` = list(Display = "Neither")))
  q <- fx_set_block(q, "BL3", "Options", list(Looping = "Question", LoopingOptions = list(
    Locator = "q://QID3/ChoiceGroup/SelectedChoices", QID = "QID3",
    Static = list(), Randomization = "None")))
  r <- data.frame(ResponseId = "A", Finished = 1, Mode = "web", QID1 = "1", QID2 = "0",
                  QID3_7 = "1", `3_QID5` = "1", `3_QID6` = "1", QID13 = "1",
                  check.names = FALSE)
  ex <- run_q(q, r)
  # "Neither" (choice id 7) is the third choice: one iteration, export prefix 3
  expect_equal(cell(ex, "A", "BL3", "iterations"), 1L)
  expect_equal(cell(ex, "A", "BL3", "points"), 4)   # QID5 2 + QID6 2
  expect_equal(attr(ex, "respondents")$n_routing_conflicts, 0L)
})

test_that("a randomised loop counts only answered iterations at the exit", {
  r <- exposure_responses()
  r$`1_QID5`[3] <- NA; r$`1_QID7`[3] <- NA            # R3 answered iteration 2 only
  expect_equal(cell(run_q(fx_raw(), r), "R3", "BL3", "iterations"), 2L)
  opts <- fx_block(fx_raw(), "BL3")$Options
  opts$LoopingOptions$Randomization <- "All"
  ex <- run_q(fx_set_block(fx_raw(), "BL3", "Options", opts), r)
  expect_equal(cell(ex, "R3", "BL3", "iterations"), 1L)
  # rebuilt from the answers alone, so flagged
  expect_true(attr(ex, "respondents")$unresolved_loops[3])
  expect_false(attr(ex, "respondents")$unresolved_loops[1])
})

test_that("a randomised loop showing a subset of iterations is left to the answers", {
  opts <- fx_block(fx_raw(), "BL3")$Options
  opts$LoopingOptions$Randomization <- "All"
  opts$LoopingOptions$RandomizationSubsetCount <- "1"
  r <- exposure_responses()
  r$`2_QID5`[1] <- NA                                  # R1 (driver 2) answered one
  ex <- run_q(fx_set_block(fx_raw(), "BL3", "Options", opts), r)
  expect_equal(cell(ex, "R1", "BL3", "iterations"), 1L)
  flag <- attr(ex, "respondents")$unresolved_loops
  expect_true(flag[1])
  # R4 left before the loop and R2 was screened out before it: not flagged
  expect_false(flag[4])
  expect_false(flag[2])
})

test_that("a screen-out after an uncertain loop keeps its flag", {
  opts <- fx_block(fx_raw(), "BL3")$Options
  opts$LoopingOptions$Randomization <- "All"
  opts$LoopingOptions$RandomizationSubsetCount <- "1"
  q <- fx_set_block(fx_raw(), "BL3", "Options", opts)
  # after the loop: end the survey for phone respondents
  gate <- list(Type = "Branch", FlowID = "FL_b_phone",
    BranchLogic = one_logic(list(LogicType = "EmbeddedField", LeftOperand = "Mode",
                                 Operator = "EqualTo", RightOperand = "phone",
                                 Type = "Expression")),
    Flow = list(list(Type = "EndSurvey", FlowID = "FL_end_phone")))
  q <- fx_with_flow(q, append(fx_flow(q), list(gate), after = 5L))   # after the loop
  r <- exposure_responses()
  r$QID10[5] <- NA; r$QID12[5] <- NA; r$QID13[5] <- NA
  ex <- run_q(q, r)
  expect_equal(cell(ex, "R5", "BL3", "outcome"), "screen_out")
  expect_true(attr(ex, "respondents")$unresolved_loops[5])
})

test_that("comma-joined codes are split only when every piece is a choice code", {
  r <- exposure_responses()[c(1, 5), ]
  r$QID3_1 <- NULL; r$QID3_2 <- NULL
  r$QID3 <- c("2,1", "A car, red")                    # codes; a label with a comma
  ex <- run_q(fx_raw(), r)
  # QID4 (shown if QID3 = car) costs 1 point in Household
  expect_equal(cell(ex, "R1", "BL2", "points"), 9)
  expect_equal(cell(ex, "R5", "BL2", "points"), 8)
})

test_that("a loop block reached through either of two branches keeps its iterations", {
  q <- fx_raw()
  fl <- fx_flow(q)
  web <- function(op) list(Type = "Branch", FlowID = paste0("FL_b_", op),
    BranchLogic = one_logic(list(LogicType = "EmbeddedField", LeftOperand = "Mode",
                                 Operator = op, RightOperand = "web", Type = "Expression")),
    Flow = list(list(Type = "Standard", ID = "BL3", FlowID = paste0("FL_3", op))))
  fl[[5]] <- NULL                                      # the plain BL3 node
  q <- fx_with_flow(q, append(fl, list(web("EqualTo"), web("NotEqualTo")), after = 4L))
  # R1 (web, finished, driver = 2) answered nothing in the loop, so only the
  # first occurrence routes it there; the second, untaken one must not erase it
  r <- exposure_responses()
  r[1, grepl("^[0-9]+_", names(r))] <- NA
  ex <- run_q(q, r)
  expect_equal(cell(ex, "R1", "BL3", "iterations"), 2L)
  # iteration 1: QID5 2 + QID6 2 (QID5 is not "child") + QID7 1; iteration 2: 2 + 2
  expect_equal(cell(ex, "R1", "BL3", "points"), 9)
  # R5 (phone) takes the second occurrence
  expect_equal(cell(ex, "R5", "BL3", "points"), 5)
})

test_that("respondent ids must be unique and present", {
  r <- exposure_responses()
  r$ResponseId[2] <- "R1"
  expect_error(run_q(fx_raw(), r), "unique")
  r$ResponseId[2] <- NA
  expect_error(run_q(fx_raw(), r), "1 missing and 0 duplicated")
  expect_error(run_q(fx_raw(), r[0, ]), "no respondents")
  # a tibble with a factor id column works
  t <- tibble::as_tibble(exposure_responses())
  t$ResponseId <- factor(t$ResponseId)
  expect_equal(cell(run_q(fx_raw(), t), "R1", "BL3", "points"), 7)
})

test_that("a loop with no recoverable iterations is flagged, not a crash", {
  q <- fx_set_block(fx_raw(), "BL3", "Options", list(Looping = "Question",
    LoopingOptions = list(Locator = "", Static = list(), Randomization = "None")))
  r <- exposure_responses()
  r <- r[, !grepl("^[0-9]+_", names(r))]
  ex <- run_q(q, r)
  expect_equal(cell(ex, "R1", "BL3", "iterations"), 0L)
  expect_true(attr(ex, "respondents")$unresolved_loops[1])
})

test_that("hidden and metadata items are reported, not counted as displayed", {
  q <- fx_set_q(fx_raw(), "QID7", "QuestionType", "Timing")
  ex <- run_q(q)
  # QID7 is shown in R1's first loop iteration; now it is a timing item
  expect_equal(cell(ex, "R1", "BL3", "items"), 3L)
  expect_equal(cell(ex, "R1", "BL3", "hidden_items"), 1L)
  expect_equal(cell(ex, "R1", "BL3", "points"), 6)
})

test_that("a block named like an ordinal is matched by name first", {
  q <- fx_set_block(fx_raw(), "BL5", "Description", "2")
  r <- exposure_responses()
  r$LastBlock <- c(NA, NA, "2", "2.5", NA)
  ex <- suppressMessages(rb_blocks(q, r, furthest = "column",
                                           furthest_col = "LastBlock"))
  expect_equal(attr(ex, "respondents")$furthest_order[3], 5)
  # "2.5" is neither a block nor an integral ordinal: falls back to answers
  expect_equal(attr(ex, "respondents")$furthest_order[4], 2)
})
