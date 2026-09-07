# Structures absent from the main demo fixture. Fixture built by
# data-raw/make_synthetic_qsf.R.

sx <- function() read_qsf(test_path("fixtures/synthetic_edge_cases.qsf"))

cat_x <- local({
  v <- NULL
  function() { if (is.null(v)) v <<- parse_qsf(sx()); v }
})
score_x <- local({
  v <- NULL
  function() { if (is.null(v)) v <<- score_burden(cat_x()); v }
})

test_that("the synthetic fixture parses to the expected 12 live questions", {
  cat <- cat_x()
  expect_equal(nrow(cat), 13L)
  expect_false(anyNA(cat$question_id))
})

test_that("a zero-question block is kept as a block but adds no questions", {
  b <- resolve_live_blocks(sx())
  expect_true("EMPTY BLOCK" %in% b$block_name)
  empty <- b[b$block_name == "EMPTY BLOCK", ]
  expect_equal(length(empty$question_ids[[1]]), 0L)
})

test_that("a question with empty text parses (0 words) and still scores", {
  cat <- cat_x(); sc <- score_x()
  expect_equal(cat$text_words[cat$question_id == "QID_notext"], 0L)
  expect_gt(sc$gfs_points[sc$question_id == "QID_notext"], 0)
})

test_that("exotic question types classify to distinct std_types", {
  cat <- cat_x()
  ty <- stats::setNames(cat$std_type, cat$question_id)
  expect_equal(ty[["QID_matmulti"]], "matrix")
  expect_equal(ty[["QID_rank"]], "ranking")
  expect_equal(ty[["QID_cs"]], "constant_sum")
  expect_equal(ty[["QID_star"]], "slider")
  expect_equal(ty[["QID_longdb"]], "descriptive")
  expect_equal(ty[["QID_sbs"]], "unknown")
})

test_that("an unmapped question type scores NA and burden_report warns it is an under-count", {
  sc <- score_x()
  sbs <- sc[sc$question_id == "QID_sbs", ]
  expect_true(is.na(sbs$gfs_points))
  expect_equal(sbs$score_flag, "unknown")

  r <- suppressWarnings(burden_report(sx(), profile = FALSE, certainty = FALSE))
  w <- paste(r$warnings, collapse = " | ")
  expect_match(w, "could not be scored", ignore.case = TRUE)
  expect_match(w, "UNDER-count", ignore.case = TRUE)
  expect_match(w, "QID_sbs")
})

test_that("Matrix/MultipleAnswer is flagged inferred, not scored as single-answer", {
  cat <- cat_x()
  row <- cat[cat$question_id == "QID_matmulti", ]
  expect_equal(row$std_type, "matrix")
  expect_equal(row$flag, "inferred")
})

test_that("every exotic type gets a positive, finite GfS score", {
  sc <- score_x()
  ex <- sc[sc$question_id %in% c("QID_matmulti", "QID_rank", "QID_cs", "QID_star", "QID_longdb"), ]
  expect_true(all(is.finite(ex$gfs_points)))
  expect_true(all(ex$gfs_points > 0))
})

test_that("a long descriptive block scores above the descriptive base", {
  sc <- score_x()
  w <- gfs_weights()
  expect_gt(sc$gfs_points[sc$question_id == "QID_longdb"], w$descriptive_base)
})

test_that("the flow resolver handles a BlockRandomizer (all sub-blocks, order kept)", {
  expect_warning(f <- resolve_flow(sx()), "BlockRandomizer")
  bids <- unique(unlist(f$block_ids))
  expect_true(all(c("BL_intro", "BL_empty") %in% bids))
})

test_that("nested branches resolve and the inner-branch block is reachable", {
  paths <- suppressWarnings(resolve_paths(sx()))
  reachable <- unique(unlist(lapply(seq_len(nrow(paths)), function(i) {
    c(paths$q_always[[i]], paths$q_maybe[[i]])
  })))
  expect_true("QID_branchq" %in% reachable)
})

test_that("an EndSurvey inside a branch produces screen-out paths", {
  f <- suppressWarnings(resolve_flow(sx()))
  expect_true(any(f$terminates_early))
  expect_true(any(!f$terminates_early))
})

test_that("display logic on an embedded-data field is a resolvable gate, not an error", {
  cat <- cat_x()
  row <- cat[cat$question_id == "QID_dl_ed", ]
  expect_true(row$has_display_logic)
  paths <- suppressWarnings(resolve_paths(sx()))
  maybe <- unique(unlist(paths$q_maybe))
  expect_true("QID_dl_ed" %in% maybe)
})

test_that("OR-across-groups display logic parses without error (AND-collapsed, per A5)", {
  cat <- cat_x()
  expect_true(cat$has_display_logic[cat$question_id == "QID_dl_or"])
  expect_silent(cc <- suppressWarnings(calculation_certainty(sx())))
  expect_equal(cc$display_logic$n_exact + cc$display_logic$n_approx,
               cc$display_logic$n_conditional)
})

test_that("burden_report runs end to end on the synthetic fixture", {
  r <- suppressWarnings(burden_report(sx(), profile = FALSE))
  expect_s3_class(r, "burden_report")
  expect_true(is.finite(bstat(r, "min")))
  r2 <- suppressWarnings(burden_report(sx(), profile = TRUE))
  expect_true(is.finite(bstat(r2, "median")))
})
