test_that("gfs_scheme() uses the published GfS 12 points/minute conversion", {
  w <- gfs_scheme()
  expect_equal(w$points_per_minute, 12)
})

test_that("gfs_scheme() takes no arguments", {
  expect_error(gfs_scheme("web"))
})

test_that("gfs_scheme() transcribes the Table 1 point values", {
  w <- gfs_scheme()
  expect_equal(w$yes_no, 1.0)
  expect_equal(w$rating_small, 2.0)
  expect_equal(w$rating_large, 3.0)
  expect_equal(w$open_essay, 6.0)
  expect_equal(w$sc_2_alt, 2.0)
})

test_that("score_burden converts est_seconds at 12 points/minute", {
  cat <- tibble::tibble(
    question_id = "Q1", flow_order = 1L, block_id = "B", block_name = "B",
    std_type = "descriptive", qualtrics_type = NA_character_,
    selector = NA_character_, subselector = NA_character_,
    n_options = NA_integer_, n_rows = NA_integer_, n_cols = NA_integer_,
    text_words = 5L, has_display_logic = FALSE,
    display_logic_refs = list(character(0)), has_validation = FALSE,
    in_loop = FALSE, loop_max = NA_integer_, flag = "auto"
  )
  sc <- score_burden(cat, gfs_scheme())
  expect_equal(sc$est_seconds, sc$gfs_points / 12 * 60)
})
