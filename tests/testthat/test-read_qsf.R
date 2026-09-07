test_that("read_qsf loads a .qsf and returns a qsf_raw object", {
  qsf <- read_qsf(demo_qsf())

  expect_s3_class(qsf, "qsf_raw")
  expect_true(all(c("SurveyEntry", "SurveyElements") %in% names(qsf)))
  expect_identical(qsf$SurveyEntry$SurveyName, "Neighbourhood Travel Survey (demo)")
})

test_that("read_qsf keeps JSON structure unsimplified (lists, not vectors)", {
  qsf <- read_qsf(demo_qsf())

  # SurveyElements must be an unnamed list of element objects
  expect_type(qsf$SurveyElements, "list")
  expect_null(names(qsf$SurveyElements))
  expect_type(qsf$SurveyElements[[1]], "list")
})

test_that("read_qsf errors clearly when given neither a file nor a survey id", {
  expect_error(read_qsf("no_such_file.qsf"), "not a readable")
})
