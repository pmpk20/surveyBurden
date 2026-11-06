# Extracted from test-burden_report.R:244

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "surveyBurden", path = "..")
attach(test_env, warn.conflicts = FALSE)

# prequel ----------------------------------------------------------------------
fx <- function() demo_qsf()
report_naive <- local({
  v <- NULL
  function() { if (is.null(v)) v <<- burden_report(fx(), profile = FALSE, certainty = FALSE); v }
})
report_full <- local({
  v <- NULL
  function() { if (is.null(v)) v <<- burden_report(fx(), certainty = FALSE); v }
})

# test -------------------------------------------------------------------------
fake <- structure(list(
    survey = tibble::tibble(
      survey_name = "Tiny", n_questions = 1L, n_blocks = 1L,
      n_paths = 1L, n_complete_paths = 1L),
    burden = structure(
      tibble::tibble(statistic = factor(c("min", "p25", "median", "p75", "max"),
                                        levels = c("min", "p25", "median", "p75", "max")),
                     points = rep(10, 5)),
      basis = "structural"),
    benchmark = list(median_points = 399, n_waves = 79L), ppm = 12
  ), class = "summary.burden_report")
out <- paste(format(fake), collapse = " ")
expect_match(out, "1 question, 1 block, 1 structural path \\(")
