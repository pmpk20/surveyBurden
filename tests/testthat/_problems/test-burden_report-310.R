# Extracted from test-burden_report.R:310

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
r <- report_full()
v <- paste(burden_verdict_line(r$burden, attr(r, "points_per_minute"),
                                 attr(r, "benchmark")$median_points,
                                 r$survey$n_complete_paths), collapse = " ")
expect_match(v, sprintf("%.1fx the benchmark", bstat(r, "median") / 399), fixed = TRUE)
