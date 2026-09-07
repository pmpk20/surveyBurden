qsf_fx <- function() read_qsf(demo_qsf())

test_that("respondent_burden() with no routes summarises the complete paths", {
  rb <- respondent_burden(qsf_fx())

  expect_s3_class(rb, "respondent_burden")
  expect_equal(nrow(rb), 2L)
  expect_true(all(c("path_id", "n_loop_blocks", "optional_blocks",
                    "floor_pts", "typical_pts", "ceiling_pts") %in% names(rb)))
  expect_true(all(rb$floor_pts <= rb$typical_pts))
  expect_true(all(rb$typical_pts <= rb$ceiling_pts))
  # both complete paths pass through both Loop & Merge blocks
  expect_true(all(rb$n_loop_blocks == 2L))
})

test_that("repeating the Loop & Merge sections lifts the ceiling above the floor", {
  rb <- respondent_burden(qsf_fx())
  expect_true(all(rb$ceiling_pts > rb$floor_pts))
})

test_that("summary_line() produces a sentence with points and minutes", {
  s <- summary_line(respondent_burden(qsf_fx()))
  expect_type(s, "character")
  expect_match(s, "GfS points")
  expect_match(s, "min")
})

test_that("respondent_burden() with routes predicts per respondent using real loop counts", {
  routes <- data.frame(
    id = 1:3,
    loop_QID9  = c(0, 4, 1),   # other-adults loop iterations
    loop_QID15 = c(0, 1, 1)    # vehicle loop iterations
  )
  pr <- respondent_burden(qsf_fx(), routes = routes)

  expect_equal(nrow(pr), 3L)
  expect_true(all(c("path_id", "matched", "pred_pts", "pred_min") %in% names(pr)))
  # respondent 1 never enters a loop -> lightest
  expect_lt(pr$pred_pts[1], pr$pred_pts[2])
  expect_lt(pr$pred_pts[1], pr$pred_pts[3])
  # more adult-loop iterations => more burden
  expect_gt(pr$pred_pts[2], pr$pred_pts[3])
  # every route corresponds to a real complete flow path
  expect_true(all(pr$matched))
})

test_that("a loop_* column with no exact id is assigned to a loop block in flow order", {
  routes <- data.frame(loop_other_adults = c(0, 3))
  pr <- respondent_burden(qsf_fx(), routes = routes)
  expect_equal(nrow(pr), 2L)
  expect_lt(pr$pred_pts[1], pr$pred_pts[2])   # first loop block picked up the column
})

test_that("visit_<block> routes a respondent onto a branch-gated path", {
  rb  <- respondent_burden(qsf_fx())
  opt <- rb$optional_blocks[lengths(rb$optional_blocks) > 0]
  skip_if(length(opt) == 0, "fixture has no branch-gated complete path")

  bid    <- opt[[1]][1]
  routes <- data.frame(loop_QID9 = 1, loop_QID15 = 1)
  routes[[paste0("visit_", bid)]] <- TRUE

  pr <- respondent_burden(qsf_fx(), routes = routes)
  expect_true(pr$matched)
})

test_that("route recovery: branch signatures all resolve to a real complete path", {
  set.seed(42)
  routes <- data.frame(
    loop_QID9  = rbinom(300, 4, 0.4),
    loop_QID15 = rbinom(300, 2, 0.5)
  )
  pr <- respondent_burden(qsf_fx(), routes = routes)
  expect_true(all(pr$matched))
})

test_that("a minimal route matches cleanly with no warning", {
  routes <- data.frame(loop_QID9 = 0, loop_QID15 = 0)
  expect_no_warning(pr <- respondent_burden(qsf_fx(), routes = routes))
  expect_true(pr$matched)
})
