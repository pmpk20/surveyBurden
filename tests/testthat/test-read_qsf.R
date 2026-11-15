
test_that("read_qsf keeps JSON structure unsimplified (lists, not vectors)", {
  qsf <- read_qsf(demo_qsf())

  # SurveyElements must be an unnamed list of element objects
  expect_type(qsf$SurveyElements, "list")
  expect_null(names(qsf$SurveyElements))
  expect_type(qsf$SurveyElements[[1]], "list")
})

