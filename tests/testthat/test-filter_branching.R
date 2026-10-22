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

test_that("the switch is off by default", {
  expect_false(gfs_scheme()$apply_filter_branching)
})

test_that("parse_qsf() marks filter and branch triggers", {
  cat <- parse_qsf(fb_qsf())
  expect_setequal(cat$question_id[cat$filter_trigger], c("QID1", "QID3", "QID4", "QID5"))
  expect_setequal(cat$question_id[cat$branch_trigger], "QID1")
})

test_that("a Displayed() reference alone does not make a filter", {
  q <- fb_qsf()
  i <- which(vapply(q$SurveyElements, function(e)
    identical(e$PrimaryAttribute, "QID9"), logical(1)))
  dl <- q$SurveyElements[[i]]$Payload$DisplayLogic
  dl[["0"]][["1"]] <- NULL                      # keep only Displayed(QID4)
  q$SurveyElements[[i]]$Payload$DisplayLogic <- dl
  cat <- parse_qsf(q)
  expect_false(cat$filter_trigger[cat$question_id == "QID4"])
})

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

test_that("a hand-built catalogue defaults to no triggers", {
  cat <- validate_catalogue(data.frame(question_id = "Q1", std_type = "single_choice",
                                       n_options = 2L))
  expect_false(cat$filter_trigger)
  expect_false(cat$branch_trigger)
  expect_equal(score_burden(cat, fb_on())$gfs_points, 1)
})

test_that("burden_report() and respondent_burden() carry the switch", {
  q <- fb_qsf()
  b0 <- burden_report(q, quiet = TRUE)
  b1 <- burden_report(q, quiet = TRUE, scheme = fb_on())
  expect_equal(b0$burden$points, burden_report(q, quiet = TRUE)$burden$points)
  # the screen-out path shows only QID1
  so <- b1$paths$status == "screen_out"
  expect_equal(b1$paths$burden_floor[so], b0$paths$burden_floor[so] + 1)
  expect_true(all(b1$burden$points >= b0$burden$points + 1))

  resp <- data.frame(ResponseId = c("R1", "R2"), Finished = c(1, 1),
                     QID1 = c("1", "2"), QID2 = c("0", NA),
                     QID3_1 = c("1", NA), QID4 = c("2", NA), QID13 = c("1", NA))
  r0 <- suppressMessages(respondent_burden(q, resp))
  r1 <- suppressMessages(respondent_burden(q, resp, scheme = fb_on()))
  # R2 declines: QID1 only (+1.0). R1: QID1 + QID3 + QID4, no loop (+2.0)
  expect_equal(r1$points - r0$points, c(2, 1))
})
