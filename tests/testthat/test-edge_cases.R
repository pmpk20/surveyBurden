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





test_that("an unmapped question type scores NA and burden_report warns it is an under-count", {
  sc <- score_x()
  sbs <- sc[sc$question_id == "QID_sbs", ]
  expect_true(is.na(sbs$gfs_points))
  expect_equal(sbs$score_flag, "unknown")

  r <- suppressWarnings(burden_report(sx(), profile = FALSE, certainty = FALSE))
  w <- paste(r$warnings, collapse = " | ")
  expect_match(w, "could not be scored", ignore.case = TRUE)
  expect_match(w, "under-counted", ignore.case = TRUE)
  expect_match(w, "QID_sbs")
})









