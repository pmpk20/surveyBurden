cat_fixture <- function() parse_qsf(demo_qsf())

test_that("parse_qsf returns a one-row-per-live-question catalogue with the expected schema", {
  cat <- cat_fixture()

  expect_s3_class(cat, "tbl_df")
  expect_equal(nrow(cat), 26L)
  expect_setequal(names(cat), c(
    "question_id", "flow_order", "block_id", "block_name",
    "std_type", "qualtrics_type", "selector", "subselector",
    "n_options", "n_rows", "n_cols", "text_words", "max_label_words",
    "label_text", "options_numeric", "question_text", "is_hidden",
    "has_display_logic", "display_logic_refs", "has_validation",
    "in_loop", "loop_max", "flag"
  ))
  expect_false(anyNA(cat$question_id))
  expect_equal(anyDuplicated(cat$question_id), 0L)
})

test_that("parse_qsf accepts a path or an already-loaded qsf_raw", {
  from_path <- parse_qsf(demo_qsf())
  from_obj  <- parse_qsf(read_qsf(demo_qsf()))
  expect_identical(from_path, from_obj)
})

test_that("parse_qsf preserves flow then within-block order", {
  cat <- cat_fixture()
  expect_false(is.unsorted(cat$flow_order))
})

test_that("parse_qsf classifies every question type present in the fixture", {
  cat <- cat_fixture()
  expect_equal(sum(cat$std_type == "single_choice"), 17L)
  expect_equal(sum(cat$std_type == "multi_choice"), 1L)
  expect_equal(sum(cat$std_type == "matrix"), 4L)
  expect_equal(sum(cat$std_type == "open_text"), 3L)
  expect_equal(sum(cat$std_type == "descriptive"), 1L)
  expect_equal(sum(cat$std_type == "unknown"), 0L)
})

test_that("parse_qsf carries block context and Loop & Merge flags onto questions", {
  cat <- cat_fixture()

  loop6 <- cat[cat$block_name == "Other adults", ]
  expect_gt(nrow(loop6), 0)
  expect_true(all(loop6$in_loop))
  expect_true(all(loop6$loop_max == 5L))

  loop8 <- cat[cat$block_name == "Vehicle details", ]
  expect_true(all(loop8$in_loop))
  expect_true(all(loop8$loop_max == 3L))

  consent <- cat[cat$block_name == "Consent", ]
  expect_true(all(!consent$in_loop))
  expect_true(all(is.na(consent$loop_max)))
})

test_that("parse_qsf classifies a known matrix question correctly", {
  cat <- cat_fixture()
  q19 <- cat[cat$question_id == "QID19", ]

  expect_equal(q19$std_type, "matrix")
  expect_equal(q19$n_rows, 7L)     # 7 travel modes
  expect_equal(q19$n_cols, 4L)     # 4 frequency options
})
