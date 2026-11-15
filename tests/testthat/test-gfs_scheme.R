test_that("gfs_scheme() uses the published GfS 12 points/minute conversion", {
  w <- gfs_scheme()
  expect_equal(w$points_per_minute, 12)
})


test_that("gfs_scheme() transcribes the Table 1 point values", {
  w <- gfs_scheme()
  expect_equal(w$yes_no, 1.0)
  expect_equal(w$rating_small, 2.0)
  expect_equal(w$rating_large, 3.0)
  expect_equal(w$open_essay, 6.0)
  expect_equal(w$sc_2_alt, 2.0)
})

