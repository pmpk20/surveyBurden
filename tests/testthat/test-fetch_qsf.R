test_that("extract_survey_id pulls SV_ ids from ids and URLs", {
  expect_equal(extract_survey_id("SV_0xIVRCCRgC1lt8a"), "SV_0xIVRCCRgC1lt8a")
  expect_equal(
    extract_survey_id("https://leedsubs.eu.qualtrics.com/survey-builder/SV_0xIVRCCRgC1lt8a/edit"),
    "SV_0xIVRCCRgC1lt8a"
  )
  expect_true(is.na(extract_survey_id("not-a-survey")))
})

test_that("as_qsf_raw passes through a .qsf-shaped definition", {
  fx <- read_qsf(demo_qsf())
  again <- as_qsf_raw(unclass(fx))
  expect_s3_class(again, "qsf_raw")
  expect_equal(length(again$SurveyElements), length(fx$SurveyElements))
})

test_that("as_qsf_raw reconstructs SurveyElements from the API shape", {
  api <- list(
    SurveyID = "SV_test", SurveyName = "T",
    Questions = list(
      QID1 = list(QuestionType = "MC", Selector = "SAVR", QuestionText = "A?",
                  Choices = list(`1` = list(Display = "x"), `2` = list(Display = "y"))),
      QID2 = list(QuestionType = "TE", Selector = "ML", QuestionText = "B?")
    ),
    Blocks = list(BL_a = list(Type = "Standard", ID = "BL_a", Description = "Blk",
                              BlockElements = list(list(Type = "Question", QuestionID = "QID1"),
                                                   list(Type = "Question", QuestionID = "QID2")))),
    SurveyFlow = list(Type = "Root", Flow = list(
      list(Type = "Standard", ID = "BL_a", FlowID = "FL_1")
    ))
  )
  q <- as_qsf_raw(api)

  expect_s3_class(q, "qsf_raw")
  expect_equal(q$SurveyEntry$SurveyName, "T")
  els <- vapply(q$SurveyElements, function(e) e$Element, character(1))
  expect_setequal(els, c("BL", "FL", "SQ", "SQ"))

  cat <- parse_qsf(q)
  expect_equal(nrow(cat), 2L)
  expect_equal(cat$std_type, c("single_choice", "open_text"))
})

test_that("normalise_base_url adds a scheme and trims path", {
  expect_equal(normalise_base_url("leedsubs.eu.qualtrics.com"), "https://leedsubs.eu.qualtrics.com")
  expect_equal(normalise_base_url("https://fra1.qualtrics.com/"), "https://fra1.qualtrics.com")
  expect_equal(normalise_base_url("https://fra1.qualtrics.com/API/v3"), "https://fra1.qualtrics.com")
})

test_that("fetch_qsf errors clearly without credentials", {
  withr::local_envvar(QUALTRICS_API_KEY = "", QUALTRICS_BASE_URL = "")
  expect_error(fetch_qsf("SV_test"), "base URL")
  expect_error(fetch_qsf("https://x.qualtrics.com/SV_test"), "token")
})

test_that("read_qsf rejects a string that is neither a file nor a survey id", {
  expect_error(read_qsf("./nope.qsf"), "not a readable")
})
