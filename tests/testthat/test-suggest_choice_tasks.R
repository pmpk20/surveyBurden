# suggest_choice_tasks(): flags questions that look like stated-choice tasks
# (an HTML table in the stem, a small single-choice answer set) for the user
# to confirm. It never scores anything itself.

sct_table <- function(n_attr) {
  rows <- vapply(seq_len(n_attr), function(i)
    sprintf("<tr><th>Attribute %d</th><td>a</td><td>b</td><td>c</td></tr>", i),
    character(1))
  paste0("<p>Which would you choose?</p><table><tr><th></th><th>Option A</th>",
         "<th>Option B</th><th>Neither</th></tr>", paste(rows, collapse = ""),
         "</table>")
}

sct_qsf <- function() {
  q <- read_qsf(test_path("fixtures", "exposure_fixture.qsf"))
  i <- which(vapply(q$SurveyElements, function(e)
    identical(e$PrimaryAttribute, "QID12"), logical(1)))
  q$SurveyElements[[i]]$Payload$QuestionText <- sct_table(4)
  q
}

test_that("a single choice with a table in its stem is suggested", {
  s <- suggest_choice_tasks(sct_qsf())
  expect_s3_class(s, "tbl_df")
  expect_equal(s$question_id, "QID12")
  expect_equal(s$n_alternatives, 3L)
  expect_equal(s$n_attributes, 4L)
  expect_true(all(c("question_id", "block_id", "n_alternatives", "n_attributes",
                    "n_in_block", "evidence") %in% names(s)))
  expect_match(s$evidence, "table")
})

test_that("a survey without table stems gives no suggestions", {
  s <- suggest_choice_tasks(read_qsf(test_path("fixtures", "exposure_fixture.qsf")))
  expect_equal(nrow(s), 0L)
  expect_true(all(c("question_id", "n_alternatives", "n_attributes") %in% names(s)))
})

test_that("suggestions plug into choice_tasks once checked", {
  q <- sct_qsf()
  s <- suggest_choice_tasks(q)
  br <- burden_report(q, quiet = TRUE, choice_tasks = s)
  # 3 alternatives (3.0) + 4 attributes (4.0)
  expect_equal(br$items$gfs_points[br$items$question_id == "QID12"], 7)
  # suggesting alone changes nothing
  expect_equal(burden_report(q, quiet = TRUE)$items$gfs_points[
    br$items$question_id == "QID12"], 2)
})

# --- other layouts seen in real surveys -------------------------------------

sct_set_text <- function(q, qid, text) {
  i <- which(vapply(q$SurveyElements, function(e)
    identical(e$PrimaryAttribute, qid), logical(1)))
  q$SurveyElements[[i]]$Payload$QuestionText <- text
  q
}

test_that("image stems repeated in a block are suggested, attributes unknown", {
  q <- read_qsf(test_path("fixtures", "exposure_fixture.qsf"))
  img <- '<p>Which do you prefer?</p><img src="https://example.org/${e://Field/task}.png">'
  q <- sct_set_text(q, "QID9", img)          # BL5 Driving: QID9, QID10
  q <- sct_set_text(q, "QID10", img)
  s <- suggest_choice_tasks(q)
  expect_setequal(s$question_id, c("QID9", "QID10"))
  expect_true(all(is.na(s$n_attributes)))
  expect_equal(s$n_alternatives[s$question_id == "QID10"], 2L)
  expect_true(all(s$n_in_block == 2L))
  expect_match(s$evidence, "image")

  # a single image question on its own is not a choice task
  q1 <- sct_set_text(read_qsf(test_path("fixtures", "exposure_fixture.qsf")), "QID9", img)
  expect_equal(nrow(suggest_choice_tasks(q1)), 0L)
})

test_that("a table in the text item before a choice question is used", {
  q <- read_qsf(test_path("fixtures", "exposure_fixture.qsf"))
  # BL5: QID9 becomes a text item holding the attribute table, QID10 the choice
  i <- which(vapply(q$SurveyElements, function(e)
    identical(e$PrimaryAttribute, "QID9"), logical(1)))
  p <- q$SurveyElements[[i]]$Payload
  q$SurveyElements[[i]]$Payload <- list(
    QuestionID = "QID9", QuestionType = "DB", Selector = "TB",
    QuestionText = sct_table(5), DataExportTag = "QID9",
    QuestionDescription = "scenario", DisplayLogic = p$DisplayLogic)
  s <- suggest_choice_tasks(q)
  expect_equal(s$question_id, "QID10")
  expect_equal(s$n_attributes, 5L)
  expect_match(s$evidence, "QID9")
})

test_that("more than five options leaves the alternative count to the user", {
  q <- read_qsf(test_path("fixtures", "exposure_fixture.qsf"))
  i <- which(vapply(q$SurveyElements, function(e)
    identical(e$PrimaryAttribute, "QID12"), logical(1)))
  q$SurveyElements[[i]]$Payload$QuestionText <- sct_table(3)
  q$SurveyElements[[i]]$Payload$Choices <- stats::setNames(
    lapply(1:7, function(k) list(Display = as.character(k))), as.character(1:7))
  s <- suggest_choice_tasks(q)
  expect_equal(s$question_id, "QID12")
  expect_true(is.na(s$n_alternatives))
  expect_match(s$evidence, "graded")
})

test_that("table rows spanning several lines are counted", {
  expect_equal(count_data_rows("<table>\n<tr>\n<th></th><th>A</th>\n</tr>\n<tr>\n<td>x</td>\n</tr>\n<tr><td>y</td></tr></table>"), 2L)
})
