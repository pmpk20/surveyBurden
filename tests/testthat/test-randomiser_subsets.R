# BlockRandomizer subsets: a randomiser that shows m of its M children
# (`SubSet`) is enumerated as choose(M, m) paths, one per combination of
# children, in survey order. Synthetic survey: BL0 holds a yes/no (1 point);
# BLA, BLB, BLC hold one single-answer grid each of 5, 10 and 15 rows with 3
# columns (2 points a row: 10, 20 and 30 points).

rs_mc <- function(qid) {
  list(QuestionID = qid, QuestionType = "MC", Selector = "SAVR", SubSelector = "TX",
       QuestionText = "Consent?", DataExportTag = qid, QuestionDescription = qid,
       Choices = list(`1` = list(Display = "Yes"), `2` = list(Display = "No")))
}
rs_grid <- function(qid, rows) {
  list(QuestionID = qid, QuestionType = "Matrix", Selector = "Likert",
       SubSelector = "SingleAnswer", QuestionText = "Rate these", DataExportTag = qid,
       QuestionDescription = qid,
       Choices = stats::setNames(lapply(seq_len(rows), function(i) list(Display = paste("row", i))),
                                 as.character(seq_len(rows))),
       Answers = stats::setNames(lapply(1:3, function(i) list(Display = paste("col", i))),
                                 as.character(1:3)))
}
rs_blk <- function(id, qid) {
  list(Type = "Standard", SubType = "", Description = id, ID = id,
       BlockElements = list(list(Type = "Question", QuestionID = qid)))
}
rs_std <- function(id) list(Type = "Standard", ID = id, FlowID = paste0("FL_", id))
rs_qsf <- function(randomiser) {
  qs <- list(rs_mc("QID0"), rs_grid("QIDA", 5), rs_grid("QIDB", 10), rs_grid("QIDC", 15))
  blocks <- list(rs_blk("BL0", "QID0"), rs_blk("BLA", "QIDA"), rs_blk("BLB", "QIDB"),
                 rs_blk("BLC", "QIDC"))
  flow <- list(rs_std("BL0"), randomiser)
  el <- c(
    list(list(Element = "BL", PrimaryAttribute = "Survey Blocks", SecondaryAttribute = "",
              Payload = stats::setNames(blocks, as.character(seq_along(blocks) - 1L))),
         list(Element = "FL", PrimaryAttribute = "Survey Flow", SecondaryAttribute = "",
              Payload = list(Type = "Root", FlowID = "FL_root", Flow = flow))),
    lapply(qs, function(p) list(Element = "SQ", PrimaryAttribute = p$QuestionID,
                                SecondaryAttribute = "", Payload = p)))
  as_qsf_raw(list(SurveyEntry = list(SurveyID = "SV_rs", SurveyName = "Randomiser subsets"),
                  SurveyElements = el))
}
rs_rand <- function(subset = 1L, children = list(rs_std("BLA"), rs_std("BLB"), rs_std("BLC"))) {
  r <- list(Type = "BlockRandomizer", FlowID = "FL_rand", EvenPresentation = TRUE,
            Flow = children)
  if (!is.null(subset)) r$SubSet <- subset
  r
}
rs_totals <- function(q) sort(suppressMessages(path_burden(q))$gfs_ceiling)

test_that("show 1 of 3 gives one path per block, not one with all three", {
  q <- rs_qsf(rs_rand(1L))
  expect_no_warning(f <- suppressMessages(resolve_flow(q)))
  expect_equal(nrow(f), 3L)
  expect_setequal(vapply(f$block_ids, paste, "", collapse = ">"),
                  c("BL0>BLA", "BL0>BLB", "BL0>BLC"))
  expect_equal(rs_totals(q), c(11, 21, 31))
})

test_that("show 2 of 3 gives the three pairs, in survey order", {
  q <- rs_qsf(rs_rand("2"))                       # Qualtrics may store a string
  f <- suppressMessages(resolve_flow(q))
  expect_setequal(vapply(f$block_ids, paste, "", collapse = ">"),
                  c("BL0>BLA>BLB", "BL0>BLA>BLC", "BL0>BLB>BLC"))
  expect_equal(rs_totals(q), c(31, 41, 51))
})

test_that("a subset equal to the number of children keeps every block, without warning", {
  q <- rs_qsf(rs_rand(3L))
  expect_no_warning(f <- suppressMessages(resolve_flow(q)))
  expect_equal(nrow(f), 1L)
  expect_equal(rs_totals(q), 61)
})

test_that("an unreadable subset keeps every block and warns", {
  for (s in list(NULL, "", "abc", 0L)) {
    q <- rs_qsf(rs_rand(s))
    expect_warning(f <- suppressMessages(resolve_flow(q)), "BlockRandomizer")
    expect_equal(nrow(f), 1L)
  }
})

test_that("a child group is chosen as a unit", {
  grp <- list(Type = "Group", FlowID = "FL_grp", Description = "pair",
              Flow = list(rs_std("BLB"), rs_std("BLC")))
  q <- rs_qsf(rs_rand(1L, children = list(rs_std("BLA"), grp)))
  f <- suppressMessages(resolve_flow(q))
  expect_setequal(vapply(f$block_ids, paste, "", collapse = ">"),
                  c("BL0>BLA", "BL0>BLB>BLC"))
})

test_that("a randomiser of embedded-data assignments adds no paths", {
  ed <- function(v) list(Type = "EmbeddedData", FlowID = paste0("FL_ed", v),
                         EmbeddedData = list(list(Field = "cond", Value = v)))
  r <- rs_rand(1L, children = list(ed("1"), ed("2"), ed("3")))
  q <- rs_qsf(r)
  expect_no_warning(f <- suppressMessages(resolve_flow(q)))
  expect_equal(nrow(f), 1L)
})

test_that("too many combinations stop with the path-space error", {
  q <- rs_qsf(rs_rand(1L))
  expect_error(suppressMessages(resolve_flow(q, max_paths = 2L)), "too large")
})

test_that("calculation_certainty() lists randomisers and whether subsets were enumerated", {
  ct <- suppressMessages(calculation_certainty(rs_qsf(rs_rand(1L))))
  r <- ct$randomisers
  expect_equal(r$flow_id, "FL_rand")
  expect_equal(r$n_children, 3L)
  expect_equal(r$subset, 1L)
  expect_true(r$enumerated)
  expect_match(paste(format(ct), collapse = "\n"), "1 of 3")

  ct0 <- suppressWarnings(suppressMessages(calculation_certainty(rs_qsf(rs_rand(NULL)))))
  expect_false(ct0$randomisers$enumerated)
  expect_true(is.na(ct0$randomisers$subset))
})

# --- respondent_burden(): which randomised blocks each respondent saw --------

# R1 answered BLA, R2 answered BLB, R3 answered nothing in the randomiser
rs_resp <- function(do = NULL) {
  grid <- function(qid, rows, who) {
    m <- matrix(NA_character_, 3, rows, dimnames = list(NULL, paste0(qid, "_", seq_len(rows))))
    m[who, ] <- "2"
    as.data.frame(m, stringsAsFactors = FALSE)
  }
  d <- cbind(data.frame(ResponseId = c("R1", "R2", "R3"), Finished = c(1, 1, 1), QID0 = "1"),
             grid("QIDA", 5, 1), grid("QIDB", 10, 2), grid("QIDC", 15, integer()))
  if (!is.null(do)) d$FL_rand_DO <- do
  d
}

test_that("the display-order column decides which randomised blocks were shown", {
  q <- rs_qsf(rs_rand(1L))
  # by flow id, by block id and by block name
  rb <- expect_no_warning(suppressMessages(respondent_burden(q, rs_resp(c("FL_BLA", "BLB", "BLC")))))
  expect_equal(rb$points, c(11, 21, 31))
  expect_equal(rb$n_randomiser_fallbacks, c(0L, 0L, 0L))
})

test_that("without a display-order column the answered blocks are used, with a warning and a count", {
  q <- rs_qsf(rs_rand(1L))
  expect_warning(rb <- suppressMessages(respondent_burden(q, rs_resp())), "FL_rand_DO")
  expect_equal(rb$points, c(11, 21, 1))
  expect_equal(rb$n_randomiser_fallbacks, c(1L, 1L, 1L))
})

test_that("a blank display-order cell falls back for that respondent only", {
  q <- rs_qsf(rs_rand(1L))
  expect_warning(rb <- suppressMessages(respondent_burden(q, rs_resp(c("FL_BLA", "", "FL_BLC")))),
                 "1 respondent")
  expect_equal(rb$points, c(11, 21, 31))
  expect_equal(rb$n_randomiser_fallbacks, c(0L, 1L, 0L))
})

test_that("a randomiser that shows every element needs no display order", {
  q <- rs_qsf(rs_rand(3L))
  rb <- expect_no_warning(suppressMessages(respondent_burden(q, rs_resp())))
  expect_equal(rb$points, c(61, 61, 61))
  expect_equal(rb$n_randomiser_fallbacks, c(0L, 0L, 0L))
})

test_that("the fallback count is reported per block row too", {
  q <- rs_qsf(rs_rand(1L))
  rb <- suppressWarnings(suppressMessages(respondent_burden(q, rs_resp(), by = "block")))
  expect_equal(attr(rb, "respondents")$n_randomiser_fallbacks, c(1L, 1L, 1L))
  shown <- rb[rb$routed_in %in% TRUE, ]
  expect_setequal(paste(shown$response_id, shown$block_id),
                  c("R1 BL0", "R1 BLA", "R2 BL0", "R2 BLB", "R3 BL0"))
})
