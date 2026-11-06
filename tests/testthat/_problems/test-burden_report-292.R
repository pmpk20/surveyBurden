# Extracted from test-burden_report.R:292

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
out <- format(report_full())
verdict_i <- grep("Median completing path", out)
instr_i   <- grep("Survey[^A-Za-z]*$", out)[1]
expect_length(verdict_i, 1L)
