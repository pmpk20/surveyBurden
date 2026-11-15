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






test_that("col_map keeps loop iterations: explicit, or from an N_ column prefix", {
  resp <- make_responses()
  ref  <- respondent_burden(qsf_fx(), resp)
  loop_cols <- grep("^[0-9]+_QID", names(resp), value = TRUE)
  qid  <- sub("^[0-9]+_", "", loop_cols)
  iter <- as.integer(sub("_.*$", "", loop_cols))

  # (a) names with no recognisable pattern; iteration given in the map
  a <- resp
  names(a)[match(loop_cols, names(a))] <- paste0("loopA_", qid, "_it", iter)
  attr(a, "col_map") <- stats::setNames(
    Map(function(q, i) list(qid = q, iteration = i), qid, iter),
    paste0("loopA_", qid, "_it", iter))
  rb_a <- respondent_burden(qsf_fx(), a)
  expect_identical(rb_a$points, ref$points)

  # (b) renamed but keeping the N_ iteration prefix; map gives the QID only
  b <- resp
  names(b)[match(loop_cols, names(b))] <- paste0(iter, "_custom_", qid)
  attr(b, "col_map") <- stats::setNames(as.list(qid), paste0(iter, "_custom_", qid))
  rb_b <- respondent_burden(qsf_fx(), b)
  expect_identical(rb_b$points, ref$points)
})

# A raw Qualtrics CSV export read with read.csv() has two extra rows under the
# header: the question-text labels and the ImportId JSON.
with_qualtrics_header_rows <- function(resp, ids = stats::setNames(names(resp), names(resp))) {
  lab <- stats::setNames(as.list(paste("Label for", names(resp))), names(resp))
  lab$ResponseId <- "Response ID"; lab$Finished <- "Finished"
  imp <- stats::setNames(as.list(sprintf('{"ImportId":"%s"}', ids[names(resp)])), names(resp))
  rbind(as.data.frame(lab, check.names = FALSE, stringsAsFactors = FALSE),
        as.data.frame(imp, check.names = FALSE, stringsAsFactors = FALSE),
        resp)
}

test_that("the ImportId row maps columns whose names match no QID or export tag", {
  resp <- make_responses()
  ref  <- respondent_burden(qsf_fx(), resp)
  qcols <- grep("QID", names(resp), value = TRUE)
  ids <- stats::setNames(names(resp), names(resp))     # ImportId = true QID name
  renamed <- resp
  names(renamed)[match(qcols, names(renamed))] <- paste0("w4_col", seq_along(qcols))
  names(ids)[match(qcols, names(ids))] <- paste0("w4_col", seq_along(qcols))
  raw <- with_qualtrics_header_rows(renamed, ids)

  rb <- suppressMessages(respondent_burden(qsf_fx(), raw))
  expect_identical(rb$points, ref$points)
})



test_that("leading Qualtrics label and ImportId rows are removed, with a message", {
  resp <- make_responses()
  ref  <- respondent_burden(qsf_fx(), resp)
  raw  <- with_qualtrics_header_rows(resp)

  expect_message(rb <- respondent_burden(qsf_fx(), raw), "2 Qualtrics header rows")
  expect_equal(nrow(rb), nrow(resp))
  expect_identical(rb$points, ref$points)
  expect_identical(rb$response_id, ref$response_id)

})





test_that("loop iterations contribute additional burden", {
  resp <- make_responses()
  # same answers outside the loops, so only the iterations differ
  cat_ <- parse_qsf(qsf_fx())
  for (qid in cat_$question_id[!cat_$in_loop]) resp[[qid]][2] <- resp[[qid]][1]
  rb <- respondent_burden(qsf_fx(), resp, loop_iterations = "observed")

  # respondent 1 (2 loop iters) > respondent 2 (1 loop iter)
  expect_gt(rb$points[1], rb$points[2])
})


test_that("export-tag column names are mapped", {
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

  rb <- respondent_burden(qsf, resp)
  expect_equal(nrow(rb), 2L)
  expect_gt(rb$points[1], 0)
})




test_that("custom id_col works", {
  resp <- make_responses()
  resp$my_id <- paste0("X", seq_len(nrow(resp)))

  rb <- respondent_burden(qsf_fx(), resp, id_col = "my_id")
  expect_equal(rb$response_id, resp$my_id)
})






test_that("descriptive text counts towards respondent burden", {
  resp <- make_responses()
  wide <- gfs_scheme(); wide$words_per_line <- 12
  narrow <- gfs_scheme(); narrow$words_per_line <- 6
  rb_12 <- respondent_burden(qsf_fx(), resp, scheme = wide)
  rb_6  <- respondent_burden(qsf_fx(), resp, scheme = narrow)

  # QID1 is descriptive text: more lines at 6 words per line, more points
  expect_gt(rb_6$points[1], rb_12$points[1])
  expect_gt(rb_12$items[1], rb_12$response_items[1])
})


test_that("a question left blank still counts towards respondent burden", {
  resp <- make_responses()
  blank <- resp
  blank$QID3[1] <- NA    # displayed to R_1 but not answered
  rb  <- respondent_burden(qsf_fx(), resp)
  rb0 <- respondent_burden(qsf_fx(), blank)
  expect_equal(rb0$points[1], rb$points[1])
})


# ---------- per-respondent words_per_line ------------------------------------



test_that("a per-respondent words_per_line changes only that respondent's text", {
  resp <- make_responses()
  rb_vec    <- respondent_burden(qsf_fx(), resp, words_per_line = c(6, 12, 12, 12))
  rb_scalar <- respondent_burden(qsf_fx(), resp, words_per_line = 12)
  rb_6      <- respondent_burden(qsf_fx(), resp, words_per_line = 6)

  expect_gt(rb_vec$points[1], rb_scalar$points[1])
  expect_equal(rb_vec$points[1], rb_6$points[1])
  expect_equal(rb_vec$points[-1], rb_scalar$points[-1])

  bl <- respondent_burden(qsf_fx(), resp, words_per_line = c(6, 12, 12, 12), by = "block")
  expect_equal(tapply(ifelse(bl$routed_in %in% TRUE, bl$points, 0), bl$response_id,
                      sum, na.rm = TRUE)[rb_vec$response_id], rb_vec$points,
               ignore_attr = TRUE)
})



