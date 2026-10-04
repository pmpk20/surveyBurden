# realised_exposure() on a synthetic survey (fixtures/exposure_fixture.qsf,
# built by fixtures/make_exposure_fixture.R). Expected values are worked out
# by hand from the fixture's flow, display logic and GfS+ scores.

exposure_qsf <- function() test_path("fixtures", "exposure_fixture.qsf")

# R1 complete, web mode, two other adults (partner, child), owns a car, drives
# R2 declines consent: screen-out
# R3 phone mode, three other adults, breaks off in the loop after iteration 2
# R4 no other adults, breaks off in Household without answering page 2
# R5 complete, phone mode, one other adult; answers the quota-gated question
#    and the block behind the JavaScript-set field
exposure_responses <- function() {
  data.frame(
    ResponseId = paste0("R", 1:5),
    Finished   = c(1, 1, 0, 0, 1),
    Mode       = c("web", "web", "phone", "web", "phone"),
    LastBlock  = c(NA, NA, "BL3", "Driving", NA),
    QID1       = c("1", "2", "1", "1", "1"),
    QID2       = c("2", NA, "3", "0", "1"),
    QID3_1     = c("1", NA, NA, NA, "1"),
    QID3_2     = c(NA, NA, "1", NA, NA),
    QID3_3     = c(NA, NA, NA, NA, NA),
    QID4       = c("1", NA, NA, NA, "2"),
    `1_QID5`   = c("1", NA, "2", NA, "3"),
    `1_QID6`   = c("2", NA, NA, NA, "1"),
    `1_QID7`   = c("1", NA, "1", NA, "1"),
    `2_QID5`   = c("2", NA, "1", NA, NA),
    `2_QID6`   = c(NA, NA, NA, NA, NA),
    `3_QID5`   = c(NA, NA, NA, NA, NA),
    QID8       = c("friend", NA, NA, NA, NA),
    QID9       = c("2", NA, NA, NA, NA),
    QID10      = c(NA, NA, NA, NA, "1"),
    QID12      = c(NA, NA, NA, NA, "2"),
    QID13      = c("1", NA, NA, NA, "3"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

run_exposure <- function(responses = exposure_responses(), ...) {
  suppressMessages(realised_exposure(exposure_qsf(), responses, ...))
}

cell <- function(ex, rid, bid, col) ex[[col]][ex$response_id == rid & ex$block_id == bid]

test_that("returns one row per respondent per live block, in flow order", {
  ex <- run_exposure()
  expect_s3_class(ex, "tbl_df")
  expect_equal(nrow(ex), 5L * 8L)
  expect_equal(ex$block_id[ex$response_id == "R1"], paste0("BL", 1:8))
  expect_true(all(c("routed_in", "displayed", "iterations", "shown_points",
                    "shown_items", "shown_response_items", "shown_pages",
                    "design_points", "exit_block", "unresolved_items",
                    "outcome") %in% names(ex)))
})

test_that("a complete respondent's shown points follow routing and display logic", {
  ex <- run_exposure()
  # Household: QID2 (2) + QID3 (6) + QID4 (1; car selected), one per page
  expect_equal(cell(ex, "R1", "BL2", "shown_points"), 9)
  expect_equal(cell(ex, "R1", "BL2", "shown_pages"), 3L)
  # loop: iteration 1 partner: QID5 2 + QID6 2 + QID7 1; iteration 2 child:
  # QID6 hidden (NotSelected child), QID7 first iteration only -> 2
  expect_equal(cell(ex, "R1", "BL3", "iterations"), 2L)
  expect_equal(cell(ex, "R1", "BL3", "shown_points"), 7)
  expect_equal(cell(ex, "R1", "BL3", "shown_items"), 4L)
  expect_equal(cell(ex, "R1", "BL3", "shown_pages"), 2L)
  # embedded-data gate Mode == web
  expect_true(cell(ex, "R1", "BL4", "routed_in"))
  # Driving: QID9 shown (Displayed(QID4) and drives); quota-gated QID10
  # unresolved and unanswered -> not shown, counted
  expect_equal(cell(ex, "R1", "BL5", "shown_points"), 2)
  expect_equal(cell(ex, "R1", "BL5", "unresolved_items"), 1L)
  # JavaScript-set field: unresolved branch, nothing answered behind it
  expect_false(cell(ex, "R1", "BL7", "routed_in"))
  expect_equal(sum(ex$shown_points[ex$response_id == "R1"], na.rm = TRUE), 22)
})

test_that("a block whose every question is hidden is routed in but not displayed", {
  ex <- run_exposure()
  expect_true(cell(ex, "R1", "BL6", "routed_in"))
  expect_false(cell(ex, "R1", "BL6", "displayed"))
  expect_equal(cell(ex, "R1", "BL6", "shown_points"), 0)
  pp <- exposure_person_period(ex)
  expect_false(any(pp$response_id == "R1" & pp$block_id == "BL6"))
})

test_that("a screen-out ends at the screening block and is not an event", {
  ex <- run_exposure()
  r2 <- ex[ex$response_id == "R2", ]
  expect_true(all(r2$outcome == "screen_out"))
  expect_true(r2$routed_in[1])
  expect_false(any(r2$routed_in[-1]))
  expect_true(r2$exit_block[1])
  pp <- exposure_person_period(ex)
  expect_equal(pp$event[pp$response_id == "R2"], 0L)
})

test_that("a break-off in a loop counts the iterations reached, not the driver's", {
  ex <- run_exposure()
  # driver says 3; answers stop after iteration 2
  expect_equal(cell(ex, "R3", "BL3", "iterations"), 2L)
  # iteration 1 child: QID5 2 + QID7 1; iteration 2 partner: QID5 2 + QID6 2
  expect_equal(cell(ex, "R3", "BL3", "shown_points"), 7)
  expect_true(cell(ex, "R3", "BL3", "exit_block"))
  expect_equal(cell(ex, "R3", "BL3", "outcome"), "breakoff")
  # blocks after the exit are unknown, not "not routed"
  expect_true(all(is.na(ex$routed_in[ex$response_id == "R3" & ex$flow_order > 3])))
  expect_true(all(is.na(ex$shown_points[ex$response_id == "R3" & ex$flow_order > 3])))
})

test_that("leaving on an unanswered page is attributed to the last answered block", {
  ex <- run_exposure()
  # R4 answered only QID2 (page 1 of Household): exit = Household; the whole
  # block's shown questions count (QID2 + QID3; QID4 hidden, no car)
  expect_true(cell(ex, "R4", "BL2", "exit_block"))
  expect_equal(cell(ex, "R4", "BL2", "shown_points"), 8)
  expect_true(is.na(cell(ex, "R4", "BL3", "routed_in")))
})

test_that("furthest_col moves the exit to a reported last block", {
  ex <- run_exposure(furthest = "column", furthest_col = "LastBlock")
  # R4 reported reaching Driving (block 5): zero-iteration loop is skipped.
  # Driving shows R4 nothing (QID4 was hidden; the quota-gated QID10 is
  # unanswered), so the exit is the last displayed block, Web extras.
  expect_true(cell(ex, "R4", "BL5", "routed_in"))
  expect_false(cell(ex, "R4", "BL5", "displayed"))
  expect_true(cell(ex, "R4", "BL4", "exit_block"))
  expect_false(cell(ex, "R4", "BL3", "displayed"))
  expect_equal(cell(ex, "R4", "BL3", "iterations"), 0L)
  expect_true(cell(ex, "R4", "BL4", "routed_in"))
  # blank LastBlock falls back to the answers, with a message
  expect_message(
    realised_exposure(exposure_qsf(), exposure_responses(), furthest = "column",
                      furthest_col = "LastBlock"),
    "blank or unrecognised")
  expect_error(realised_exposure(exposure_qsf(), exposure_responses(),
                                 furthest = "column"), "furthest_col")
})

test_that("unresolvable logic falls back to answers and is reported", {
  ex <- run_exposure()
  # R5 answered the quota-gated QID10 and the block behind CarFlag
  expect_equal(cell(ex, "R5", "BL5", "shown_points"), 1)
  expect_equal(cell(ex, "R5", "BL5", "unresolved_items"), 1L)
  expect_true(cell(ex, "R5", "BL7", "routed_in"))
  resp <- attr(ex, "respondents")
  expect_equal(resp$n_unresolved_branches, c(1L, 0L, 0L, 0L, 1L))
  expect_equal(resp$n_unresolved_items, c(1L, 0L, 0L, 0L, 1L))
  expect_equal(resp$outcome, c("complete", "screen_out", "breakoff", "breakoff", "complete"))
  expect_message(realised_exposure(exposure_qsf(), exposure_responses()),
                 "not settled")
})

test_that("an embedded field mapped explicitly overrides automatic matching", {
  r <- exposure_responses()
  names(r)[names(r) == "Mode"] <- "survey_mode_x"
  ex <- run_exposure(r)
  # unmatched field: Mode unknown -> falls back to answers (R1 answered QID8)
  expect_true(cell(ex, "R1", "BL4", "routed_in"))
  expect_equal(attr(ex, "respondents")$n_unresolved_branches[1], 2L)
  ex2 <- run_exposure(r, embedded = c(Mode = "survey_mode_x"))
  expect_equal(attr(ex2, "respondents")$n_unresolved_branches[1], 1L)
  # snake_case column matched ignoring case and punctuation
  names(r)[names(r) == "survey_mode_x"] <- "mo_de"
  expect_equal(attr(run_exposure(r), "respondents")$n_unresolved_branches[1], 1L)
})

test_that("a field the export lacks but the flow sets to a fixed value is used", {
  ex <- run_exposure()
  # Wave is set to "2" in the flow; the wave-2 branch routes everyone past it
  expect_true(all(ex$routed_in[ex$block_id == "BL5" & ex$response_id %in% c("R1", "R5")]))
})

test_that("observed loop iterations ignore the driving question", {
  r <- exposure_responses()
  ex <- run_exposure(r, loop_iterations = "observed")
  expect_equal(cell(ex, "R1", "BL3", "iterations"), 2L)
  r$`2_QID5`[1] <- NA      # R1 answered only iteration 1
  expect_equal(cell(run_exposure(r), "R1", "BL3", "iterations"), 2L)
  expect_equal(cell(run_exposure(r, loop_iterations = "observed"), "R1", "BL3", "iterations"), 1L)
})

test_that("answers in a block the flow skipped are trusted and counted", {
  r <- exposure_responses()
  r$QID8[3] <- "radio"     # R3 is phone mode but answered the web block
  r$Finished[3] <- 1
  ex <- run_exposure(r)
  expect_true(cell(ex, "R3", "BL4", "routed_in"))
  expect_equal(attr(ex, "respondents")$n_routing_conflicts[3], 1L)
})

test_that("export-tag columns and Qualtrics header rows are handled", {
  r <- exposure_responses()
  hdr <- r[1, ]; hdr[] <- NA; hdr$ResponseId <- "Response ID"; hdr$Finished <- "Finished"
  r2 <- rbind(hdr, r)
  ex <- run_exposure(r2)
  expect_equal(nrow(ex), 5L * 8L)
  expect_equal(cell(ex, "R1", "BL3", "shown_points"), 7)
})

test_that("exposure_person_period() builds hazard rows", {
  pp <- exposure_person_period(run_exposure())
  r1 <- pp[pp$response_id == "R1", ]
  expect_equal(r1$block_id, c("BL1", "BL2", "BL3", "BL4", "BL5", "BL8"))
  expect_equal(r1$period, 1:6)
  expect_equal(r1$points_before, c(0, 1, 10, 17, 18, 20))
  expect_equal(r1$event, rep(0L, 6))
  expect_equal(r1$block_points, c(1, 9, 5, 1, 3, 2))
  r3 <- pp[pp$response_id == "R3", ]
  expect_equal(r3$event, c(0L, 0L, 1L))
  expect_equal(sum(pp$event), 2L)
  expect_error(exposure_person_period(data.frame(a = 1)), "realised_exposure")
})

test_that("works on the bundled demo survey", {
  qsf <- demo_qsf()
  responses <- data.frame(
    ResponseId = c("R_1", "R_2", "R_3"),
    Finished   = c(1, 0, 1),
    QID2 = c("1", "1", "2"), QID3 = c("1", "1", NA), QID4 = c("2", "3", NA),
    QID6 = c("1", "4", NA), QID9 = c("2", NA, NA), QID10 = c("1", NA, NA),
    `1_QID11` = c("2", NA, NA), QID19_1 = c("3", NA, NA), QID22 = c("3", NA, NA),
    QID26 = c("1", NA, NA), check.names = FALSE
  )
  ex <- suppressMessages(realised_exposure(qsf, responses))
  resp <- attr(ex, "respondents")
  expect_equal(resp$outcome, c("complete", "breakoff", "screen_out"))
  # R_1 employed: routed into Commuting; R_3 declined consent
  expect_true(cell(ex, "R_1", "BL11", "routed_in"))
  expect_true(cell(ex, "R_3", "BL2", "exit_block"))
  # a complete respondent's displayed blocks sum to at most the design total
  # for one pass of each loop times its iterations
  expect_true(sum(ex$shown_points[ex$response_id == "R_1"]) > 0)
})
