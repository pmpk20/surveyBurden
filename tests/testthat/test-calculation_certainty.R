test_that("branch sources are described as questions, stored values or quotas", {
  f <- surveyBurden:::branch_source_line
  expect_equal(f(3, c("QID2", "QID3")),
               "3 branches depend on answers to questions in the survey (QID2, QID3). Every possible outcome of each branch is included.")
  expect_match(f(16, c("@SP_05", "@SP_8")), "stored values such as panel variables (SP_05, SP_8)",
               fixed = TRUE)
  expect_no_match(f(16, "@SP_05"), "answers", fixed = TRUE)
  expect_match(f(17, c("@qo://QO_a/QuotaMet", "@qo://QO_a/QuotaNotMet", "@conjoint", "QID9")),
               "answers to questions in the survey (QID9), stored values such as panel variables (conjoint) and whether a quota is full (QO_a)",
               fixed = TRUE)
})
