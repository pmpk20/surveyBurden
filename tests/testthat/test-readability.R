fx <- function() demo_qsf()

test_that("burden_report returns a readability diagnostics component", {
  r <- burden_report(fx(), profile = FALSE, certainty = FALSE)
  expect_true("readability" %in% names(r))
  rd <- r$readability
  expect_true(all(c("stem_threshold", "label_threshold",
                    "long_stems", "long_labels") %in% names(rd)))
  expect_s3_class(rd$long_stems, "data.frame")
  expect_s3_class(rd$long_labels, "data.frame")
  expect_true(all(c("question_id", "text_words") %in% names(rd$long_stems)))
})

test_that("stem_warning_threshold controls how many stems are flagged", {
  hi <- burden_report(fx(), profile = FALSE, certainty = FALSE, stem_warning_threshold = 250L)
  lo <- burden_report(fx(), profile = FALSE, certainty = FALSE, stem_warning_threshold = 8L)
  expect_lte(nrow(hi$readability$long_stems), nrow(lo$readability$long_stems))
  expect_true(all(hi$readability$long_stems$text_words > 250L))
})

test_that("label_warning_threshold flags long matrix labels only", {
  r <- burden_report(fx(), profile = FALSE, certainty = FALSE, label_warning_threshold = 3L)
  ll <- r$readability$long_labels
  expect_true(all(ll$max_label_words > 3L))
})

test_that("readability diagnostics never change the GfS scores", {
  a <- burden_report(fx(), profile = FALSE, certainty = FALSE, stem_warning_threshold = 5L,
                     label_warning_threshold = 1L)
  b <- burden_report(fx(), profile = FALSE, certainty = FALSE, stem_warning_threshold = 500L,
                     label_warning_threshold = 500L)
  expect_equal(bstat(a, "max"), bstat(b, "max"))
  expect_equal(sort(a$blocks$gfs_points), sort(b$blocks$gfs_points))
})

test_that("the printed report shows a Readability diagnostics section", {
  r <- burden_report(fx(), profile = FALSE, certainty = FALSE)
  out <- format(r)
  expect_true(any(grepl("Readability diagnostics", out)))
})

test_that("words_per_line is exposed on burden_report and moves descriptive burden", {
  hi <- burden_report(fx(), profile = FALSE, certainty = FALSE, words_per_line = 6)
  lo <- burden_report(fx(), profile = FALSE, certainty = FALSE, words_per_line = 30)
  expect_gt(bstat(hi, "max"), bstat(lo, "max"))
})

test_that("a long-stem summary line reaches the warnings when the threshold bites", {
  r <- burden_report(fx(), profile = FALSE, certainty = FALSE, stem_warning_threshold = 25L)
  w <- paste(r$warnings, collapse = " | ")
  expect_match(w, "stem", ignore.case = TRUE)
})
