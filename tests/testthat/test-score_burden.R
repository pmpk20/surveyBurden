# One synthetic catalogue row, schema matching parse_qsf() output.
cat_row <- function(std_type, ..., selector = NA_character_, subselector = NA_character_,
                    n_options = NA_integer_, n_rows = NA_integer_, n_cols = NA_integer_,
                    text_words = 0L, label_text = NA_character_, options_numeric = FALSE,
                    question_text = "", is_hidden = FALSE, flag = "auto") {
  tibble::tibble(
    question_id = "QID1", flow_order = 1L, block_id = "BL_1", block_name = "B",
    std_type = std_type, qualtrics_type = NA_character_,
    selector = selector, subselector = subselector,
    n_options = as.integer(n_options), n_rows = as.integer(n_rows),
    n_cols = as.integer(n_cols), text_words = as.integer(text_words),
    label_text = label_text, options_numeric = options_numeric,
    question_text = question_text, is_hidden = is_hidden,
    has_display_logic = FALSE, display_logic_refs = list(character(0)),
    has_validation = FALSE, in_loop = FALSE, loop_max = NA_integer_, flag = flag,
    ...
  )
}
score1 <- function(...) score_burden(cat_row(...))

test_that("single choice scores by option count", {
  expect_equal(score1("single_choice", selector = "SAVR", n_options = 2)$gfs_points, 1.0)
  expect_equal(score1("single_choice", selector = "SAVR", n_options = 5)$gfs_points, 2.0)
  expect_equal(score1("single_choice", selector = "SAVR", n_options = 9)$gfs_points, 3.0)
})

test_that("every scored item carries a plain-language score_basis", {
  r <- score1("single_choice", selector = "SAVR", n_options = 2)
  expect_type(r$score_basis, "character")
  expect_true(nzchar(r$score_basis))
})

test_that("dropdowns score as ratings and are inferred, never manual", {
  small <- score1("single_choice", selector = "DL", n_options = 4)
  expect_equal(small$gfs_points, 2.0)
  expect_equal(small$score_flag, "inferred")

  big <- score1("single_choice", selector = "DL", n_options = 14)
  expect_equal(big$gfs_points, 3.0)
  expect_equal(big$score_flag, "inferred")
})

test_that("a numeric-looking dropdown with a quantity cue scores as a numeric answer", {
  age <- score1("single_choice", selector = "DL", n_options = 75,
                options_numeric = TRUE, question_text = "How old are you?")
  expect_equal(age$gfs_points, 1.0)
  expect_equal(age$score_flag, "inferred")
  expect_match(age$score_basis, "numeric", ignore.case = TRUE)
})

test_that("a short numeric dropdown with no quantity cue stays a rating (could be ordinal codes)", {
  r <- score1("single_choice", selector = "DL", n_options = 5, options_numeric = TRUE,
              question_text = "Please rate the following")
  expect_equal(r$gfs_points, 2.0)
})

test_that("a large nominal single-select gets a diagnostic note in score_basis", {
  r <- score1("single_choice", selector = "DL", n_options = 13,
              question_text = "How did you travel?")
  expect_equal(r$gfs_points, 3.0)
  expect_match(r$score_basis, "nominal", ignore.case = TRUE)
})

test_that("a CSS/JS-hidden question scores zero", {
  r <- score1("single_choice", selector = "SAVR", n_options = 5, is_hidden = TRUE)
  expect_equal(r$gfs_points, 0)
  expect_equal(r$score_flag, "inferred")
  expect_match(r$score_basis, "hidden", ignore.case = TRUE)
})

test_that("a slider with a units label scores as a numeric answer", {
  r <- score1("slider", label_text = "duration in minutes")
  expect_equal(r$gfs_points, 1.0)
  expect_equal(r$score_flag, "inferred")
})

test_that("a slider with a rating scale label scores as a rating", {
  r <- score1("slider", label_text = "strongly disagree | disagree | neutral | agree | strongly agree")
  expect_equal(r$gfs_points, 2.0)
  expect_equal(r$score_flag, "inferred")
})

test_that("multi-select adds points per additional option (Table 1: half-open)", {
  # < 8 possibilities: 2.0 + 2.0 per additional
  expect_equal(score1("multi_choice", selector = "MAVR", n_options = 7)$gfs_points, 2.0 + 2.0 * 6)
  # >= 8 possibilities: 4.0 + 3.0 per additional
  expect_equal(score1("multi_choice", selector = "MAVR", n_options = 10)$gfs_points, 4.0 + 3.0 * 9)
})

test_that("matrix scores per row by column count", {
  expect_equal(score1("matrix", n_rows = 11, n_cols = 7)$gfs_points, 11 * 3.0)
  expect_equal(score1("matrix", n_rows = 6, n_cols = 5)$gfs_points, 6 * 2.0)
})

test_that("multiple-answer matrix scores every cell as a trivial yes/no decision", {
  # each of the n_rows x n_cols cells is one binary decision, discounted for
  # grid working-memory efficiency (0.5). See gfs_weights()$matrix_cell_multi.
  r <- score1("matrix", n_rows = 12, n_cols = 3, subselector = "MultipleAnswer", flag = "inferred")
  expect_equal(r$gfs_points, 12 * 3 * 0.5)
  expect_equal(r$score_flag, "inferred")
  expect_match(r$score_basis, "cell", ignore.case = TRUE)
})

test_that("multiple-answer matrix score is orientation-invariant (rows <-> cols)", {
  a <- score1("matrix", n_rows = 12, n_cols = 3, subselector = "MultipleAnswer")
  b <- score1("matrix", n_rows = 3,  n_cols = 12, subselector = "MultipleAnswer")
  expect_equal(a$gfs_points, b$gfs_points)
})

test_that("open text: essay vs short answer", {
  expect_equal(score1("open_text", selector = "ML")$gfs_points, 6.0)
  expect_equal(score1("open_text", selector = "SL")$gfs_points, 1.0)
})

test_that("descriptive text scales with length (Table 1: +1.0 per extra line)", {
  expect_equal(score1("descriptive", text_words = 10)$gfs_points, 2.0)  # 1 line, <= 3
  # 200 words / 12 words-per-line = 17 lines; 14 beyond the first 3
  expect_equal(score1("descriptive", text_words = 200)$gfs_points, 2.0 + 14.0)
})

test_that("zero-burden and trivial item types", {
  expect_equal(score1("timing")$gfs_points, 0)
  expect_equal(score1("meta")$gfs_points, 0)
  expect_equal(score1("captcha")$gfs_points, 0.5)
})

test_that("unknown types score NA and keep the unknown flag", {
  r <- score1("unknown", flag = "unknown")
  expect_true(is.na(r$gfs_points))
  expect_equal(r$score_flag, "unknown")
})

test_that("estimated time uses 12 GfS points per minute", {
  r <- score1("matrix", n_rows = 4, n_cols = 5)  # 8 points
  expect_equal(r$gfs_points, 8.0)
  expect_equal(r$est_seconds, 8.0 / 12 * 60)
})

test_that("weights are overridable", {
  w <- gfs_weights()
  w$rating_small <- 5.0
  r <- score_burden(cat_row("single_choice", selector = "SAVR", n_options = 4), weights = w)
  expect_equal(r$gfs_points, 5.0)
})

test_that("score_burden on the demo catalogue adds columns for every row", {
  cat <- parse_qsf(demo_qsf())
  scored <- score_burden(cat)

  expect_equal(nrow(scored), 26L)
  expect_true(all(c("gfs_points", "est_seconds", "score_flag") %in% names(scored)))
  # the demo fixture has no unmapped question types
  expect_equal(sum(is.na(scored$gfs_points)), 0L)
  # sanity: all-shown total in a believable range
  expect_gt(sum(scored$gfs_points), 90)
  expect_lt(sum(scored$gfs_points), 200)
})
