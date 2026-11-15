# Minimal synthetic Qualtrics question payloads.
payload <- function(...) utils::modifyList(
  list(QuestionID = "QID1", QuestionText = "Pick one.", Choices = NULL, Answers = NULL),
  list(...)
)
choices <- function(n) stats::setNames(rep(list(list(Display = "x")), n), seq_len(n))






test_that("dropdown MC is single_choice but flagged inferred", {
  p <- payload(QuestionType = "MC", Selector = "DL", Choices = choices(87))
  r <- classify_question(p)

  expect_equal(r$std_type, "single_choice")
  expect_equal(r$n_options, 87L)
  expect_equal(r$flag, "inferred")
})











test_that("a question hidden with CSS on a Qualtrics selector is flagged is_hidden", {
  p <- payload(QuestionType = "TE", Selector = "SL",
               QuestionText = "<style>.QuestionOuter { display: none !important; }</style> Hidden loop counter")
  expect_true(classify_question(p)$is_hidden)
})








