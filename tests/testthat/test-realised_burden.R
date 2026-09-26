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
                    "predicted_minutes", "words_per_line") %in% names(rb)))
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


test_that("Finished accepts logical, numeric and text encodings; unknown is NA", {
  fin <- function(v) detect_finished(data.frame(Finished = v, stringsAsFactors = FALSE))

  expect_identical(fin(c(TRUE, FALSE, NA)), c(TRUE, FALSE, NA))
  expect_identical(fin(c(1, 0, NA)), c(TRUE, FALSE, NA))
  expect_identical(fin(c(1L, 0L)), c(TRUE, FALSE))
  expect_identical(fin(c("1", "0", "")), c(TRUE, FALSE, NA))
  expect_identical(fin(c("TRUE", "FALSE", "True", "false", " true ")),
                   c(TRUE, FALSE, TRUE, FALSE, TRUE))
  expect_identical(fin(c("Yes", "No", "y", "n")), c(TRUE, FALSE, TRUE, FALSE))
  expect_identical(fin(factor(c("1", "0"))), c(TRUE, FALSE))
  # anything unrecognised is unknown, not "did not finish"
  expect_identical(fin(c("2", "maybe", "0.5")), c(NA, NA, NA))

  # no Finished column at all -> all unknown
  expect_identical(detect_finished(data.frame(x = 1:2)), c(NA, NA))
})


test_that("col_map keeps loop iterations: explicit, or from an N_ column prefix", {
  resp <- make_responses()
  ref  <- realised_burden(qsf_fx(), resp)
  loop_cols <- grep("^[0-9]+_QID", names(resp), value = TRUE)
  qid  <- sub("^[0-9]+_", "", loop_cols)
  iter <- as.integer(sub("_.*$", "", loop_cols))

  # (a) names with no recognisable pattern; iteration given in the map
  a <- resp
  names(a)[match(loop_cols, names(a))] <- paste0("loopA_", qid, "_it", iter)
  attr(a, "col_map") <- stats::setNames(
    Map(function(q, i) list(qid = q, iteration = i), qid, iter),
    paste0("loopA_", qid, "_it", iter))
  rb_a <- realised_burden(qsf_fx(), a)
  expect_identical(rb_a$realised_points, ref$realised_points)
  expect_identical(rb_a$n_questions_answered, ref$n_questions_answered)

  # (b) renamed but keeping the N_ iteration prefix; map gives the QID only
  b <- resp
  names(b)[match(loop_cols, names(b))] <- paste0(iter, "_custom_", qid)
  attr(b, "col_map") <- stats::setNames(as.list(qid), paste0(iter, "_custom_", qid))
  rb_b <- realised_burden(qsf_fx(), b)
  expect_identical(rb_b$realised_points, ref$realised_points)
})

# A raw Qualtrics CSV export read with read.csv() has two extra rows under the
# header: the question-text labels and the ImportId JSON.
with_qualtrics_header_rows <- function(resp) {
  lab <- stats::setNames(as.list(paste("Label for", names(resp))), names(resp))
  lab$ResponseId <- "Response ID"; lab$Finished <- "Finished"
  imp <- stats::setNames(as.list(sprintf('{"ImportId":"%s"}', names(resp))), names(resp))
  rbind(as.data.frame(lab, check.names = FALSE, stringsAsFactors = FALSE),
        as.data.frame(imp, check.names = FALSE, stringsAsFactors = FALSE),
        resp)
}

test_that("leading Qualtrics label and ImportId rows are removed, with a message", {
  resp <- make_responses()
  ref  <- realised_burden(qsf_fx(), resp)
  raw  <- with_qualtrics_header_rows(resp)

  expect_message(rb <- realised_burden(qsf_fx(), raw), "2 Qualtrics header rows")
  expect_equal(nrow(rb), nrow(resp))
  expect_identical(rb$realised_points, ref$realised_points)
  expect_identical(rb$response_id, ref$response_id)

  # a per-respondent words_per_line given for the raw rows is trimmed to match
  wpl <- c(NA, NA, 10, 12, 14, 16)
  rb_w <- suppressMessages(realised_burden(qsf_fx(), raw, words_per_line = wpl))
  expect_identical(rb_w$words_per_line, c(10, 12, 14, 16))
})

test_that("unrecognised or non-leading rows are kept", {
  resp <- make_responses()
  expect_no_message(rb <- realised_burden(qsf_fx(), resp))
  expect_equal(nrow(rb), 4L)

  # a label row that is not at the top is data, not a header: keep it
  mid <- rbind(resp[1:2, ], with_qualtrics_header_rows(resp)[1, ], resp[3:4, ])
  expect_no_message(rb2 <- realised_burden(qsf_fx(), mid))
  expect_equal(nrow(rb2), 5L)

  # col_map survives the header-row removal
  raw <- with_qualtrics_header_rows(resp)
  attr(raw, "col_map") <- list(QID1 = "QID2")
  expect_identical(attr(drop_qualtrics_header_rows(raw, quiet = TRUE)$data, "col_map"),
                   list(QID1 = "QID2"))
})

test_that("col_map takes precedence over automatic column matching", {
  resp <- data.frame(ResponseId = "R_1", QID1 = "x")
  attr(resp, "col_map") <- list(QID1 = "QID2")
  cm <- build_col_map(qsf_fx(), resp, parse_qsf(qsf_fx())$question_id)
  expect_identical(cm$QID1$qid, "QID2")
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


test_that("realised_minutes uses the scheme points_per_minute", {
  resp <- make_responses()
  w <- gfs_scheme()
  rb <- realised_burden(qsf_fx(), resp, scheme = w)

  expect_equal(rb$realised_minutes, rb$realised_points / w$points_per_minute)
})


# ---------- per-respondent words_per_line ------------------------------------

test_that("words_per_line = NULL uses default from weights (backward compat)", {
  resp <- make_responses()
  rb_default <- realised_burden(qsf_fx(), resp)
  rb_null    <- realised_burden(qsf_fx(), resp, words_per_line = NULL)

  expect_equal(rb_default$realised_points, rb_null$realised_points)
})


test_that("scalar words_per_line overrides default for all respondents", {
  resp <- make_responses()
  rb_12 <- realised_burden(qsf_fx(), resp, words_per_line = 12)
  rb_6  <- realised_burden(qsf_fx(), resp, words_per_line = 6)

  # QID1 is descriptive (139 words). At wpl=6 it scores 23; at wpl=12 it scores

  # 11. Respondents who answered QID1 should have 12 more points at wpl=6.
  # Respondent 1 answered QID1 (non-NA), respondent 4 answered nothing.
  expect_gt(rb_6$realised_points[1], rb_12$realised_points[1])
  expect_equal(rb_6$realised_points[4], rb_12$realised_points[4])  # both 0
})


test_that("per-respondent words_per_line vector gives different scores", {
  resp <- make_responses()
  n <- nrow(resp)
  # respondent 1 gets wpl=6 (phone), rest get wpl=12 (desktop)
  wpl <- c(6, 12, 12, 12)

  rb_vec    <- realised_burden(qsf_fx(), resp, words_per_line = wpl)
  rb_scalar <- realised_burden(qsf_fx(), resp, words_per_line = 12)

  # respondent 1 answered QID1 (descriptive) so should differ
  expect_gt(rb_vec$realised_points[1], rb_scalar$realised_points[1])
  # respondent 2 has wpl=12 in both, so should match
  expect_equal(rb_vec$realised_points[2], rb_scalar$realised_points[2])
  # respondent 4 answered nothing, so 0 regardless
  expect_equal(rb_vec$realised_points[4], 0)
})


test_that("predicted_points ignores per-respondent words_per_line", {
  resp <- make_responses()
  wpl <- c(6, 6, 12, 12)

  rb_vec    <- realised_burden(qsf_fx(), resp, words_per_line = wpl)
  rb_default <- realised_burden(qsf_fx(), resp)

  # predicted_points is structural — should use default wpl for all

  expect_equal(rb_vec$predicted_points, rb_default$predicted_points)
})


test_that("words_per_line of wrong length errors", {
  resp <- make_responses()
  expect_error(
    realised_burden(qsf_fx(), resp, words_per_line = c(6, 12)),
    "words_per_line"
  )
})
