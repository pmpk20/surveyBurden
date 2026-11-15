


test_that("display_logic fixture has correct burden range bracketing", {
  path <- system.file("extdata", "demo_display_logic.qsf", package = "surveyBurden")
  skip_if(path == "", message = "fixture not installed")
  rpt <- burden_report(read_qsf(path), quiet = TRUE)

  expect_false(anyNA(rpt$burden$points))
  expect_true(bstat(rpt, "min") <= bstat(rpt, "median"))
  expect_true(bstat(rpt, "median") <= bstat(rpt, "max"))
})
