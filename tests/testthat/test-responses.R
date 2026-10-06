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


test_that("finished column is correctly detected", {
  resp <- make_responses()
  rb <- respondent_burden(qsf_fx(), resp)

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

test_that("display-order, timing and meta columns are not answers", {
  resp <- make_responses()
  ref  <- respondent_burden(qsf_fx(), resp)
  # respondent 4 answered nothing, but Qualtrics fills these automatically
  auto <- c(QID1_DO = "QID1_DO", QID2_DO_1 = "QID2_DO",
            t_first = "QID3_FIRST_CLICK", t_submit = "QID3_PAGE_SUBMIT",
            m_browser = "QID4_BROWSER")
  for (col in names(auto)) resp[[col]] <- "1"
  ids <- c(stats::setNames(names(resp), names(resp)))
  ids[names(auto)] <- auto

  rb <- suppressMessages(respondent_burden(qsf_fx(), with_qualtrics_header_rows(resp, ids)))
  expect_identical(rb$points, ref$points)

  # without an ImportId row, `_DO` and QID-named timing columns are not answers
  resp$QID3_FIRST_CLICK <- "1.2"
  rb2 <- respondent_burden(qsf_fx(),
                         resp[, c(names(make_responses()), "QID1_DO", "QID2_DO_1", "QID3_FIRST_CLICK")])
  expect_identical(rb2$points, ref$points)
})

test_that("respondent_burden() reads a CSV file path", {
  resp <- make_responses()
  ref  <- respondent_burden(qsf_fx(), resp)
  tmp  <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  utils::write.csv(with_qualtrics_header_rows(resp), tmp, row.names = FALSE, na = "")
  rb <- suppressMessages(respondent_burden(qsf_fx(), tmp))
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

test_that("unrecognised or non-leading rows are kept", {
  resp <- make_responses()
  expect_no_message(rb <- respondent_burden(qsf_fx(), resp))
  expect_equal(nrow(rb), 4L)

  # a label row that is not at the top is data, not a header: keep it
  mid <- rbind(resp[1:2, ], with_qualtrics_header_rows(resp)[1, ], resp[3:4, ])
  expect_no_message(rb2 <- respondent_burden(qsf_fx(), mid))
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
  rb <- respondent_burden(qsf_fx(), resp)

  expect_equal(rb$response_id, paste0("R_", 1:4))
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


test_that("no mappable columns gives an informative error", {
  resp <- data.frame(foo = 1:3, bar = 4:6)
  expect_error(respondent_burden(qsf_fx(), resp), "mapped to question ids")
})


test_that("custom id_col works", {
  resp <- make_responses()
  resp$my_id <- paste0("X", seq_len(nrow(resp)))

  rb <- respondent_burden(qsf_fx(), resp, id_col = "my_id")
  expect_equal(rb$response_id, resp$my_id)
})


test_that("one row per respondent, in input order, with the documented columns", {
  resp <- make_responses()
  rb <- respondent_burden(qsf_fx(), resp)

  expect_s3_class(rb, "tbl_df")
  expect_equal(nrow(rb), 4L)
  expect_identical(names(rb), c(
    "response_id", "finished", "outcome", "points", "minutes", "items",
    "response_items", "pages", "furthest_order", "n_unresolved_items",
    "n_unresolved_branches", "unresolved_loops", "n_routing_conflicts"))
  expect_equal(rb$finished, c(TRUE, TRUE, FALSE, FALSE))
})


test_that("respondent points are the block points summed over routed-in blocks", {
  resp <- make_responses()
  rb <- respondent_burden(qsf_fx(), resp)
  bl <- respondent_burden(qsf_fx(), resp, by = "block")

  routed <- bl$routed_in %in% TRUE
  by_hand <- tapply(ifelse(routed, bl$points, 0), bl$response_id, sum, na.rm = TRUE)
  expect_equal(rb$points, unname(as.numeric(by_hand[rb$response_id])))
  expect_equal(rb$minutes, rb$points / gfs_scheme()$points_per_minute)
  expect_identical(attr(bl, "respondents")$outcome, rb$outcome)
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

test_that("words_per_line = NULL uses the scheme's value", {
  resp <- make_responses()
  expect_equal(respondent_burden(qsf_fx(), resp)$points,
               respondent_burden(qsf_fx(), resp, words_per_line = 12)$points)
})

test_that("a scalar words_per_line applies to every respondent", {
  resp <- make_responses()
  narrow <- gfs_scheme(); narrow$words_per_line <- 6
  expect_equal(respondent_burden(qsf_fx(), resp, words_per_line = 6)$points,
               respondent_burden(qsf_fx(), resp, scheme = narrow)$points)
})

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

test_that("a per-respondent words_per_line given for raw rows is trimmed with the header rows", {
  resp <- make_responses()
  raw  <- with_qualtrics_header_rows(resp)
  ref  <- respondent_burden(qsf_fx(), resp, words_per_line = c(6, 12, 8, 10))
  rb   <- suppressMessages(respondent_burden(qsf_fx(), raw,
                                             words_per_line = c(NA, NA, 6, 12, 8, 10)))
  expect_equal(rb$points, ref$points)
})

test_that("words_per_line of the wrong length or value errors", {
  resp <- make_responses()
  expect_error(respondent_burden(qsf_fx(), resp, words_per_line = c(6, 12)),
               "words_per_line")
  expect_error(respondent_burden(qsf_fx(), resp, words_per_line = 0), "words_per_line")
})
