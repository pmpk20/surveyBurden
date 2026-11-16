test_that("weighted_quantile picks the right order statistics", {
  expect_equal(weighted_quantile(c(1, 2, 3, 4), c(1, 1, 1, 1), c(0, .5, 1)), c(1, 2, 4))
  expect_equal(weighted_quantile(c(10, 20), c(3, 1), 0.5), 10)
})

test_that("the maximum is the heaviest value however small its weight", {
  # A path with ~1e20 display-logic combinations gives its heaviest values
  # weights of ~1e-20. The maximum must still be the heaviest value, and a
  # value with zero weight must not count.
  x <- c(100, 200, 300, 400)
  expect_equal(weighted_quantile(x, c(1, 1, 1e-20, 0), c(0, 1)), c(100, 300))
  expect_equal(weighted_quantile(x, c(0, 1, 1, 1e-20), 0), 200)
})


test_that("convolve_dist adds burdens and multiplies weights", {
  a <- data.frame(burden = c(0, 10), weight = c(1, 1))
  b <- data.frame(burden = c(0, 5),  weight = c(2, 1))
  d <- convolve_dist(a, b)
  expect_setequal(d$burden, c(0, 5, 10, 15))
  expect_equal(d$weight[d$burden == 0], 2)
  expect_equal(sum(d$weight), 6)
})

# shared fixture computation
.profile_cache <- local({
  v <- NULL
  function() {
    if (is.null(v)) v <<- path_burden_profile(
      read_qsf(demo_qsf())
    )
    v
  }
})





test_that("each path's profile weights are model weights summing to 1", {
  d <- .profile_cache()
  # equal weight per modelled state, normalised per path, so pooling complete
  # paths in burden_report() gives every path equal total weight
  totals <- vapply(d$profile, function(p) sum(p$weight), numeric(1))
  expect_equal(totals, rep(1, nrow(d)))
  expect_true(all(vapply(d$profile, function(p) all(p$weight > 0), logical(1))))
})
