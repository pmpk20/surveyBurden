# Extracted from test-burden_report.R:302

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
no_complete_qsf <- function() {
  q <- read_qsf(demo_qsf())
  fl <- which(vapply(q$SurveyElements,
                     function(e) identical(e$Element, "FL"), logical(1)))
  q$SurveyElements[[fl]]$Payload$Flow <- c(
    list(list(Type = "EndSurvey", FlowID = "F_kill")),
    q$SurveyElements[[fl]]$Payload$Flow
  )
  q
}

# test -------------------------------------------------------------------------
v <- paste(burden_verdict_line(
    report_full()$burden, 12, 399, report_full()$survey$n_complete_paths),
    collapse = " ")
expect_match(v, "Median completing path: 123 GfS\\+ points, ~10 min")
expect_match(v, "0[.]3x the benchmark median of 399")
expect_match(v, "ranges 106-143 points [(]9-12 min[)] across 2 completing paths")
