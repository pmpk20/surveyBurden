# Minimal synthetic Qualtrics question payloads.
payload <- function(...) utils::modifyList(
  list(QuestionID = "QID1", QuestionText = "Pick one.", Choices = NULL, Answers = NULL),
  list(...)
)
choices <- function(n) stats::setNames(rep(list(list(Display = "x")), n), seq_len(n))

test_that("single-answer multiple choice is single_choice with option count", {
  p <- payload(QuestionType = "MC", Selector = "SAVR", SubSelector = "TX",
               Choices = choices(4))
  r <- classify_question(p)

  expect_equal(r$std_type, "single_choice")
  expect_equal(r$n_options, 4L)
  expect_equal(r$flag, "auto")
})

test_that("max_label_words is the longest response-option label in words", {
  p <- payload(QuestionType = "MC", Selector = "SAVR",
               Choices = stats::setNames(list(
                 list(Display = "Yes"),
                 list(Display = "No, none of the above apply to my situation")
               ), 1:2))
  r <- classify_question(p)
  expect_equal(r$max_label_words, 9L)
})

test_that("max_label_words is NA when a question carries no labels", {
  p <- payload(QuestionType = "TE", Selector = "SL", Choices = NULL, Answers = NULL)
  r <- classify_question(p)
  expect_true(is.na(r$max_label_words))
})

test_that("max_label_words spans matrix rows and answer columns", {
  p <- payload(QuestionType = "Matrix", Selector = "Likert", SubSelector = "SingleAnswer",
               Choices = stats::setNames(list(list(Display = "short row")), 1),
               Answers = stats::setNames(list(list(Display = "a rather long answer option label sits here")), 1))
  r <- classify_question(p)
  expect_equal(r$max_label_words, 8L)
})

test_that("multi-answer multiple choice is multi_choice", {
  p <- payload(QuestionType = "MC", Selector = "MAVR", SubSelector = "TX",
               Choices = choices(7))
  r <- classify_question(p)

  expect_equal(r$std_type, "multi_choice")
  expect_equal(r$n_options, 7L)
})

test_that("dropdown MC is single_choice but flagged inferred", {
  p <- payload(QuestionType = "MC", Selector = "DL", Choices = choices(87))
  r <- classify_question(p)

  expect_equal(r$std_type, "single_choice")
  expect_equal(r$n_options, 87L)
  expect_equal(r$flag, "inferred")
})

test_that("Likert matrix reports rows and columns", {
  p <- payload(QuestionType = "Matrix", Selector = "Likert", SubSelector = "SingleAnswer",
               Choices = choices(13), Answers = choices(5))
  r <- classify_question(p)

  expect_equal(r$std_type, "matrix")
  expect_equal(r$n_rows, 13L)
  expect_equal(r$n_cols, 5L)
  expect_equal(r$flag, "auto")
})

test_that("multiple-answer matrix is flagged inferred", {
  p <- payload(QuestionType = "Matrix", Selector = "Likert", SubSelector = "MultipleAnswer",
               Choices = choices(3), Answers = choices(4))
  expect_equal(classify_question(p)$flag, "inferred")
})

test_that("bipolar matrix is still a matrix", {
  p <- payload(QuestionType = "Matrix", Selector = "Bipolar",
               Choices = choices(10), Answers = choices(5))
  r <- classify_question(p)
  expect_equal(r$std_type, "matrix")
  expect_equal(r$n_rows, 10L)
})

test_that("multi-line text is open_text", {
  p <- payload(QuestionType = "TE", Selector = "ML")
  expect_equal(classify_question(p)$std_type, "open_text")
})

test_that("single-line text is open_text, flagged inferred", {
  p <- payload(QuestionType = "TE", Selector = "SL")
  r <- classify_question(p)
  expect_equal(r$std_type, "open_text")
  expect_equal(r$flag, "inferred")
})

test_that("sliders, descriptive text, timing, meta and captcha are recognised", {
  expect_equal(classify_question(payload(QuestionType = "Slider", Selector = "HSLIDER"))$std_type, "slider")
  expect_equal(classify_question(payload(QuestionType = "Slider", Selector = "STAR"))$std_type, "slider")
  expect_equal(classify_question(payload(QuestionType = "DB", Selector = "TB"))$std_type, "descriptive")
  expect_equal(classify_question(payload(QuestionType = "Timing", Selector = "PageTimer"))$std_type, "timing")
  expect_equal(classify_question(payload(QuestionType = "Meta", Selector = "Browser"))$std_type, "meta")
  expect_equal(classify_question(payload(QuestionType = "Captcha", Selector = "V2"))$std_type, "captcha")
})

test_that("unmapped question types classify as unknown", {
  p <- payload(QuestionType = "PGR", Selector = "DragAndDrop")
  r <- classify_question(p)
  expect_equal(r$std_type, "unknown")
  expect_equal(r$flag, "unknown")
})

test_that("text_words counts words in the stem with HTML stripped", {
  p <- payload(QuestionType = "MC", Selector = "SAVR",
               QuestionText = "<p>How <strong>often</strong> do you travel?</p>",
               Choices = choices(3))
  expect_equal(classify_question(p)$text_words, 5L)
})

test_that("question_text is HTML-stripped, whitespace-collapsed and truncated", {
  p <- payload(QuestionType = "MC", Selector = "SAVR",
               QuestionText = "<p>How  <strong>often</strong>\ndo you travel?</p>",
               Choices = choices(3))
  expect_equal(classify_question(p)$question_text, "How often do you travel?")
})

test_that("question_text truncates long stems with an ellipsis", {
  long <- paste(rep("word", 100), collapse = " ")
  p <- payload(QuestionType = "MC", Selector = "SAVR", QuestionText = long, Choices = choices(2))
  qt <- classify_question(p)$question_text
  expect_lte(nchar(qt), 203L)
  expect_match(qt, "\\.\\.\\.$")
})

test_that("a question hidden with CSS on a Qualtrics selector is flagged is_hidden", {
  p <- payload(QuestionType = "TE", Selector = "SL",
               QuestionText = "<style>.QuestionOuter { display: none !important; }</style> Hidden loop counter")
  expect_true(classify_question(p)$is_hidden)
})

test_that("a question hidden via QuestionJS is flagged is_hidden", {
  p <- payload(QuestionType = "MC", Selector = "SAVR", Choices = choices(2),
               QuestionJS = "jQuery('#Buttons').hide(); jQuery('.QuestionOuter').css('display','none');")
  expect_true(classify_question(p)$is_hidden)
})

test_that("an ordinary visible question is not is_hidden", {
  p <- payload(QuestionType = "MC", Selector = "SAVR", Choices = choices(3))
  expect_false(classify_question(p)$is_hidden)
})

test_that("options_numeric is TRUE when every choice label is a number", {
  p <- payload(QuestionType = "MC", Selector = "DL",
               Choices = stats::setNames(lapply(16:90, function(i) list(Display = as.character(i))),
                                         seq_len(75)))
  expect_true(classify_question(p)$options_numeric)
})

test_that("options_numeric is FALSE for word labels", {
  p <- payload(QuestionType = "MC", Selector = "SAVR",
               Choices = stats::setNames(list(list(Display = "Yes"), list(Display = "No")), 1:2))
  expect_false(classify_question(p)$options_numeric)
})

test_that("label_text joins response and answer labels, lowercased; NA when none", {
  p <- payload(QuestionType = "Slider", Selector = "HSLIDER",
               Answers = stats::setNames(list(list(Display = "Duration in Minutes")), 1))
  expect_match(classify_question(p)$label_text, "duration in minutes")

  bare <- payload(QuestionType = "TE", Selector = "SL")
  expect_true(is.na(classify_question(bare)$label_text))
})

test_that("sliders are flagged inferred (not in GfS Table 1)", {
  expect_equal(classify_question(payload(QuestionType = "Slider", Selector = "HSLIDER"))$flag,
               "inferred")
})

test_that("display logic and forced-response validation are detected", {
  p <- payload(
    QuestionType = "MC", Selector = "SAVR", Choices = choices(2),
    DisplayLogic = list("0" = list("0" = list(QuestionID = "QID9"))),
    Validation = list(Settings = list(ForceResponse = "ON"))
  )
  r <- classify_question(p)
  expect_true(r$has_display_logic)
  expect_true(r$has_validation)
  expect_equal(r$display_logic_refs[[1]], "QID9")
})
