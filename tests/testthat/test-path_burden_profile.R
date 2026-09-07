test_that("weighted_quantile picks the right order statistics", {
  expect_equal(weighted_quantile(c(1, 2, 3, 4), c(1, 1, 1, 1), c(0, .5, 1)), c(1, 2, 4))
  expect_equal(weighted_quantile(c(10, 20), c(3, 1), 0.5), 10)
})

test_that("group_sum totals weights by rounded burden", {
  d <- group_sum(c(1.0, 1.04, 2.0), c(1, 1, 3))
  expect_equal(d$burden, c(1.0, 2.0))
  expect_equal(d$weight, c(2, 3))
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

test_that("path_burden_profile returns a per-path structural burden profile", {
  d <- .profile_cache()

  expect_s3_class(d, "tbl_df")
  expect_equal(nrow(d), 4L)
  expect_true(all(c("path_id", "terminates_early", "n_gates",
                    "burden_min", "burden_median", "burden_max", "profile") %in% names(d)))

  full <- d[!d$terminates_early, ]
  expect_true(all(full$burden_min <= full$burden_median))
  expect_true(all(full$burden_median <= full$burden_max))
})

test_that("the enumerated profile sits inside the floor/ceiling band and is narrower", {
  band <- path_burden(read_qsf(demo_qsf()))
  prof <- .profile_cache()

  m <- merge(band[, c("path_id", "terminates_early", "gfs_floor", "gfs_ceiling")],
             prof[, c("path_id", "burden_min", "burden_max")], by = "path_id")

  expect_true(all(m$burden_min >= m$gfs_floor - 5))
  expect_true(all(m$burden_max <= m$gfs_ceiling + 5))

  # a complete path's enumerated spread is tighter than its raw floor/ceiling band
  full <- m[!m$terminates_early, ]
  narrower <- (full$burden_max - full$burden_min) < (full$gfs_ceiling - full$gfs_floor)
  expect_true(all(narrower))
})

test_that("median across full paths is well inside the floor/ceiling extremes", {
  d <- .profile_cache()
  full <- d[!d$terminates_early, ]
  pooled <- do.call(rbind, full$profile)
  med <- weighted_quantile(pooled$burden, pooled$weight, 0.5)

  expect_gt(med, min(full$burden_min))
  expect_lt(med, max(full$burden_max))
})

test_that("the profile's weight column is a sub-state count, not a probability", {
  d <- .profile_cache()
  full <- d[!d$terminates_early, ]
  # weights need not sum to 1 -- they are counts of feasible sub-states
  totals <- vapply(full$profile, function(p) sum(p$weight), numeric(1))
  expect_true(any(totals != 1))
})
