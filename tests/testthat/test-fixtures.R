test_that("demo_simple_linear.qsf parses and reports without error", {
  path <- system.file("extdata", "demo_simple_linear.qsf", package = "surveyBurden")
  skip_if(path == "", message = "fixture not installed")
  qsf <- read_qsf(path)
  rpt <- burden_report(qsf, certainty = FALSE, quiet = TRUE)

  expect_s3_class(rpt, "burden_report")
  expect_equal(rpt$instrument$n_questions, 15L)
  expect_equal(rpt$instrument$n_blocks, 3L)
  expect_equal(rpt$instrument$n_paths, 1L)
  expect_equal(rpt$instrument$n_loop_blocks, 0L)
  expect_equal(rpt$instrument$n_branches, 0L)
})

test_that("demo_display_logic.qsf parses and reports without error", {
  path <- system.file("extdata", "demo_display_logic.qsf", package = "surveyBurden")
  skip_if(path == "", message = "fixture not installed")
  qsf <- read_qsf(path)
  rpt <- burden_report(qsf, certainty = FALSE, quiet = TRUE)

  expect_s3_class(rpt, "burden_report")
  expect_equal(rpt$instrument$n_questions, 30L)
  expect_equal(rpt$instrument$n_blocks, 5L)
  expect_equal(rpt$instrument$n_paths, 2L)
  expect_equal(rpt$instrument$n_loop_blocks, 0L)

  cert <- calculation_certainty(qsf)
  expect_equal(cert$display_logic$n_conditional, 17L)
  expect_equal(cert$display_logic$n_approx, 0L)
})

test_that("demo_large_branching.qsf parses and reports without error", {
  path <- system.file("extdata", "demo_large_branching.qsf", package = "surveyBurden")
  skip_if(path == "", message = "fixture not installed")
  qsf <- read_qsf(path)
  rpt <- burden_report(qsf, certainty = FALSE, quiet = TRUE)

  expect_s3_class(rpt, "burden_report")
  expect_equal(rpt$instrument$n_questions, 52L)
  expect_equal(rpt$instrument$n_blocks, 10L)
  expect_equal(rpt$instrument$n_loop_blocks, 2L)
  expect_gte(rpt$instrument$n_paths, 4L)
  expect_true(all(rpt$paths$burden_floor <= rpt$paths$burden_ceiling))
})

test_that("display_logic fixture has correct burden range bracketing", {
  path <- system.file("extdata", "demo_display_logic.qsf", package = "surveyBurden")
  skip_if(path == "", message = "fixture not installed")
  rpt <- burden_report(read_qsf(path), quiet = TRUE)

  expect_false(anyNA(rpt$burden$points))
  expect_true(bstat(rpt, "min") <= bstat(rpt, "median"))
  expect_true(bstat(rpt, "median") <= bstat(rpt, "max"))
})
