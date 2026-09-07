qsf_fx <- function() read_qsf(demo_qsf())

test_that("path_burden returns a floor/ceiling band per flow path", {
  pb <- path_burden(qsf_fx())

  expect_s3_class(pb, "tbl_df")
  expect_equal(nrow(pb), 4L)
  expect_true(all(c("path_id", "terminates_early", "n_blocks",
                    "n_q_floor", "n_q_ceiling",
                    "gfs_floor", "gfs_ceiling",
                    "min_minutes", "max_minutes", "n_gates") %in% names(pb)))

  expect_true(all(pb$gfs_floor <= pb$gfs_ceiling))
  expect_true(all(pb$n_q_floor <= pb$n_q_ceiling))
})

test_that("full paths carry real burden; screen-outs carry less", {
  pb <- path_burden(qsf_fx())
  full <- pb[!pb$terminates_early, ]
  outs <- pb[pb$terminates_early, ]

  expect_true(all(full$gfs_floor > 100))
  expect_lt(min(outs$gfs_ceiling), max(full$gfs_ceiling))
})

test_that("loop blocks inflate the ceiling above the floor", {
  pb <- path_burden(qsf_fx())
  full <- pb[!pb$terminates_early, ]
  # the longest full path visits both loop blocks; ceiling (loops x max)
  # should sit clearly above its floor (loops x 1)
  widest <- full[which.max(full$gfs_ceiling), ]
  expect_gt(widest$gfs_ceiling, widest$gfs_floor * 1.4)
})

test_that("burden numbers are in a believable range for the demo survey", {
  pb <- path_burden(qsf_fx())
  full <- pb[!pb$terminates_early, ]

  expect_gt(min(full$gfs_floor), 100)
  expect_lt(max(full$gfs_ceiling), 1000)
})

test_that("weights flow through to path_burden", {
  w <- gfs_weights()
  w$rating_small <- w$rating_small * 10
  base <- path_burden(qsf_fx())
  bumped <- path_burden(qsf_fx(), weights = w)
  expect_gt(sum(bumped$gfs_ceiling), sum(base$gfs_ceiling))
})
