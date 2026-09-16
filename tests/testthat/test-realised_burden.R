qsf_fx <- function() read_qsf(demo_qsf())

# Build a minimal fake response data frame that matches the demo QSF.
# The demo has 26 questions (QID1-QID26). QID9 drives the first loop block and
# QID15 drives the second. We give each respondent different answer patterns.
make_responses <- function() {
  qsf <- qsf_fx()
  cat <- parse_qsf(qsf)

  # header: ResponseId, Finished, one column per non-loop QID
  non_loop_qids <- cat$question_id[!cat$in_loop]
  # for loop QIDs, create iteration-prefixed columns
  loop_qids <- cat$question_id[cat$in_loop]
  loop_blk <- unique(cat$block_id[cat$in_loop])

  resp <- data.frame(
    ResponseId = paste0("R_", 1:4),
    Finished   = c("1", "1", "0", "0"),
    stringsAsFactors = FALSE
  )

  # fill non-loop columns with non-blank for "answered"
  for (qid in non_loop_qids) {
    resp[[qid]] <- c("1", "2", "1", NA)
  }

  # fill loop columns: respondent 1 does 2 iters, respondent 2 does 1, others 0
  for (qid in loop_qids) {
    resp[[paste0("1_", qid)]] <- c("1", "1", NA, NA)   # iteration 1
    resp[[paste0("2_", qid)]] <- c("1", NA, NA, NA)     # iteration 2
  }

  resp
}


test_that("realised_burden() returns the right structure", {
  resp <- make_responses()
  rb <- realised_burden(qsf_fx(), resp)

  expect_s3_class(rb, "tbl_df")
  expect_equal(nrow(rb), 4L)
  expect_true(all(c("response_id", "finished", "furthest_block",
                    "n_questions_answered", "realised_points",
                    "realised_minutes", "predicted_points",
                    "predicted_minutes") %in% names(rb)))
})


test_that("complete respondents get higher realised burden than dropouts", {
  resp <- make_responses()
  rb <- realised_burden(qsf_fx(), resp)

  # respondent 1 answered everything including 2 loop iters -> highest

  # respondent 4 answered nothing -> lowest (0)
  expect_gt(rb$realised_points[1], rb$realised_points[4])
  expect_equal(rb$realised_points[4], 0)
})


test_that("finished column is correctly detected", {
  resp <- make_responses()
  rb <- realised_burden(qsf_fx(), resp)

  expect_equal(rb$finished, c(TRUE, TRUE, FALSE, FALSE))
})


test_that("ResponseId is detected as the id column", {
  resp <- make_responses()
  rb <- realised_burden(qsf_fx(), resp)

  expect_equal(rb$response_id, paste0("R_", 1:4))
})


test_that("loop iterations contribute additional burden", {
  resp <- make_responses()
  rb <- realised_burden(qsf_fx(), resp)

  # respondent 1 (2 loop iters) > respondent 2 (1 loop iter)
  # both answered all non-loop questions
  expect_gt(rb$realised_points[1], rb$realised_points[2])
})


test_that("realised_burden works with ExportTag-based column names", {
  qsf <- qsf_fx()
  cat <- parse_qsf(qsf)
  non_loop <- cat$question_id[!cat$in_loop]

  # the demo QSF has DataExportTag == QID (same values), so rename to simulate
  # custom tags by using the same names. The mapping should still work because
  # the ExportTag lookup matches.
  resp <- data.frame(
    ResponseId = c("R_1", "R_2"),
    Finished   = c("1", "0"),
    stringsAsFactors = FALSE
  )
  for (qid in non_loop[1:5]) {
    resp[[qid]] <- c("1", NA)
  }

  rb <- realised_burden(qsf, resp)
  expect_equal(nrow(rb), 2L)
  expect_gt(rb$realised_points[1], 0)
})


test_that("realised_burden errors informatively with no mappable columns", {
  resp <- data.frame(foo = 1:3, bar = 4:6)
  expect_error(realised_burden(qsf_fx(), resp), "mapped to question ids")
})


test_that("predicted_points is present and comparable", {
  resp <- make_responses()
  rb <- realised_burden(qsf_fx(), resp)

  # predicted should be non-NA for respondents who answered questions
  expect_true(!is.na(rb$predicted_points[1]))
  # predicted is typically >= realised (structural assumes all questions shown)
  # but loop differences can shift this, so just check it's positive
  expect_true(rb$predicted_points[1] > 0)
})


test_that("custom id_col works", {
  resp <- make_responses()
  resp$my_id <- paste0("X", seq_len(nrow(resp)))

  rb <- realised_burden(qsf_fx(), resp, id_col = "my_id")
  expect_equal(rb$response_id, resp$my_id)
})


test_that("realised_minutes uses the weights points_per_minute", {
  resp <- make_responses()
  w <- gfs_weights()
  rb <- realised_burden(qsf_fx(), resp, weights = w)

  expect_equal(rb$realised_minutes, rb$realised_points / w$points_per_minute)
})
