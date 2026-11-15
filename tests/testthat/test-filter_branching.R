# GfS filter (0.5) and branching (0.5) points, behind the scheme switch
# `apply_filter_branching` (off by default). A question earns 0.5 per role:
# "filter" when its answer drives another question's display logic,
# "branching" when its answer is tested by a flow Branch. Only answered
# questions earn points; embedded fields, loop, quota and Displayed()
# references earn nothing.
#
# Exposure fixture: QID1 (consent) is tested by the decline Branch and by
# QID11's display logic -> 1.0. QID3 (QID4), QID5 (QID6) and QID4 (QID9,
# Selected) are filters -> 0.5 each. QID4's Displayed() literal, QID7's loop
# literal, QID10's quota literal and the Mode / Wave / CarFlag field branches
# give nothing.

fb_qsf <- function() read_qsf(test_path("fixtures", "exposure_fixture.qsf"))
fb_on <- function() { s <- gfs_scheme(); s$apply_filter_branching <- TRUE; s }
fb_pts <- function(sc) stats::setNames(sc$gfs_points, sc$question_id)




test_that("switched off, scores are unchanged; on, triggers gain 0.5 per role", {
  cat <- parse_qsf(fb_qsf())
  off <- score_burden(cat)
  on  <- score_burden(cat, fb_on())
  d <- fb_pts(on) - fb_pts(off)
  expect_equal(d[["QID1"]], 1.0)
  expect_equal(unname(d[c("QID3", "QID4", "QID5")]), c(0.5, 0.5, 0.5))
  expect_true(all(d[setdiff(names(d), c("QID1", "QID3", "QID4", "QID5"))] == 0))
  b1 <- on$score_basis[on$question_id == "QID1"]
  expect_match(b1, "filter")
  expect_match(b1, "branching")
  expect_equal(on$score_flag[on$question_id == "QID3"], "inferred")
  # the point values come from the scheme
  s <- fb_on(); s$filter <- 1; s$branching <- 2
  expect_equal(fb_pts(score_burden(cat, s))[["QID1"]] - fb_pts(off)[["QID1"]], 3)
})


