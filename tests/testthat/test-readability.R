fx <- function() demo_qsf()




test_that("readability diagnostics never change the GfS scores", {
  a <- burden_report(fx(), profile = FALSE, certainty = FALSE, stem_warning_threshold = 5L,
                     label_warning_threshold = 1L)
  b <- burden_report(fx(), profile = FALSE, certainty = FALSE, stem_warning_threshold = 500L,
                     label_warning_threshold = 500L)
  expect_equal(bstat(a, "max"), bstat(b, "max"))
  expect_equal(sort(a$blocks$gfs_points), sort(b$blocks$gfs_points))
})



