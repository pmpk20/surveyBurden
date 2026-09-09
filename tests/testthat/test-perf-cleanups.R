# Behaviour pins for the performance-review cleanups (R3-R9). Each asserts the
# refactor did not change an observable contract.

# --- R6: one combined BlockRandomizer warning, not one per randomiser ---------

test_that("multiple BlockRandomizers raise a single combined warning naming them", {
  q  <- read_qsf(test_path("fixtures/synthetic_edge_cases.qsf"))
  fl <- which(vapply(q$SurveyElements,
                     function(e) identical(e$Element, "FL"), logical(1)))
  flow  <- q$SurveyElements[[fl]]$Payload$Flow
  rnd_i <- which(vapply(flow, function(n) identical(n$Type, "BlockRandomizer"),
                        logical(1)))[1]
  extra <- flow[[rnd_i]]
  extra$FlowID <- "FL_rnd_synthetic_2"
  q$SurveyElements[[fl]]$Payload$Flow <- append(flow, list(extra), after = rnd_i)

  warns <- testthat::capture_warnings(resolve_flow(q))
  rnd   <- grep("andomiz|andomis", warns, value = TRUE)
  expect_length(rnd, 1L)
  expect_match(rnd, "2")
})

test_that("a single BlockRandomizer still warns once", {
  warns <- testthat::capture_warnings(
    resolve_flow(read_qsf(test_path("fixtures/synthetic_edge_cases.qsf"))))
  expect_length(grep("andomiz|andomis", warns, value = TRUE), 1L)
})

# --- R9: the exact-enumeration cap is one shared constant --------------------

test_that("component_dist and dl_certainty share one exact_cap default", {
  expect_identical(formals(component_dist)$exact_cap,
                   formals(dl_certainty)$exact_cap)
  expect_equal(eval(formals(component_dist)$exact_cap), 5000L)
})

# --- R3: HTML is stripped once and the derived fields are unchanged ----------

test_that("classify_question stem fields are unchanged by the single-strip refactor", {
  p <- list(QuestionID = "QID1", QuestionType = "MC", Selector = "SAVR",
            QuestionText = "<div class='x'>How <b>often</b> do you   travel?</div>",
            Choices = stats::setNames(rep(list(list(Display = "x")), 3), 1:3))
  r <- classify_question(p)
  expect_equal(r$question_text, "How often do you travel?")
  expect_equal(r$text_words, 5L)
})
