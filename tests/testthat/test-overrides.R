# Item-level score overrides (`overrides =`) across the high-level API, on
# the synthetic exposure fixture. QID2 (Household block, no display logic, on
# every complete path) scores 2 points; overriding it to 10 adds 8 points to
# every complete path and to every respondent who saw it.

exposure_qsf_ov <- function() read_qsf(test_path("fixtures", "exposure_fixture.qsf"))

# same five respondents as test-respondent_burden.R
exposure_responses <- function() {
  data.frame(
    ResponseId = paste0("R", 1:5),
    Finished   = c(1, 1, 0, 0, 1),
    Mode       = c("web", "web", "phone", "web", "phone"),
    LastBlock  = c(NA, NA, "BL3", "Driving", NA),
    QID1       = c("1", "2", "1", "1", "1"),
    QID2       = c("2", NA, "3", "0", "1"),
    QID3_1     = c("1", NA, NA, NA, "1"),
    QID3_2     = c(NA, NA, "1", NA, NA),
    QID3_3     = c(NA, NA, NA, NA, NA),
    QID4       = c("1", NA, NA, NA, "2"),
    `1_QID5`   = c("1", NA, "2", NA, "3"),
    `1_QID6`   = c("2", NA, NA, NA, "1"),
    `1_QID7`   = c("1", NA, "1", NA, "1"),
    `2_QID5`   = c("2", NA, "1", NA, NA),
    `2_QID6`   = c(NA, NA, NA, NA, NA),
    `3_QID5`   = c(NA, NA, NA, NA, NA),
    QID8       = c("friend", NA, NA, NA, NA),
    QID9       = c("2", NA, NA, NA, NA),
    QID10      = c(NA, NA, NA, NA, "1"),
    QID12      = c(NA, NA, NA, NA, "2"),
    QID13      = c("1", NA, NA, NA, "3"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

test_that("score_overrides() sets points, flag and basis for the named items", {
  sc <- score_burden(parse_qsf(exposure_qsf_ov()))
  out <- score_overrides(sc, c(QID2 = 10))
  row <- out[out$question_id == "QID2", ]
  expect_equal(row$gfs_points, 10)
  expect_equal(row$score_flag, "manual")
  expect_equal(row$score_basis, "user override")
  other <- out$question_id != "QID2"
  expect_equal(out[other, ], sc[other, ])
  expect_identical(score_overrides(sc, NULL), sc)
})

test_that("unknown, unnamed, duplicated or invalid overrides error clearly", {
  sc <- score_burden(parse_qsf(exposure_qsf_ov()))
  expect_error(score_overrides(sc, c(QID999 = 5)), "QID999")
  expect_error(score_overrides(sc, c(5)), "named")
  expect_error(score_overrides(sc, c(QID2 = 5, QID2 = 6)), "more than once")
  expect_error(score_overrides(sc, c(QID2 = NA_real_)), "non-negative")
  expect_error(score_overrides(sc, c(QID2 = -1)), "non-negative")
  expect_error(score_overrides(sc, c(QID2 = "5")), "numeric")
})

test_that("burden_report() reflects an override in items, burden, paths and certainty", {
  q <- exposure_qsf_ov()
  base <- burden_report(q, quiet = TRUE)
  ov   <- burden_report(q, quiet = TRUE, overrides = c(QID2 = 10))

  it <- ov$items[ov$items$question_id == "QID2", ]
  expect_equal(it$gfs_points, 10)
  expect_equal(it$score_flag, "manual")
  expect_equal(it$score_basis, "user override")

  expect_equal(ov$burden$points, base$burden$points + 8)
  done <- base$paths$status == "complete"
  expect_equal(ov$paths$burden_median[done], base$paths$burden_median[done] + 8)
  expect_equal(ov$paths$burden_floor[done], base$paths$burden_floor[done] + 8)
  expect_equal(ov$blocks$gfs_points[ov$blocks$block_id == "BL2"],
               base$blocks$gfs_points[base$blocks$block_id == "BL2"] + 8)

  expect_equal(ov$certainty$scores$manual, base$certainty$scores$manual + 1L)
  expect_equal(ov$certainty$scores$inferred, base$certainty$scores$inferred - 1L)
})

test_that("path_burden_profile() and path_burden() reflect an override", {
  q <- exposure_qsf_ov()
  b0 <- path_burden_profile(q)
  b1 <- path_burden_profile(q, overrides = c(QID2 = 10))
  done <- !b0$terminates_early
  expect_equal(b1$burden_max[done], b0$burden_max[done] + 8)
  expect_equal(b1$burden_min[done], b0$burden_min[done] + 8)

  p0 <- path_burden(q)
  p1 <- path_burden(q, overrides = c(QID2 = 10))
  expect_equal(p1$gfs_ceiling[!p0$terminates_early],
               p0$gfs_ceiling[!p0$terminates_early] + 8)
})

test_that("calculation_certainty() counts overridden items as manual", {
  q <- exposure_qsf_ov()
  c0 <- calculation_certainty(q)
  c1 <- calculation_certainty(q, overrides = c(QID2 = 10, QID3 = 4))
  expect_equal(c1$scores$manual, c0$scores$manual + 2L)
})

test_that("respondent_burden() reflects an override for respondents shown the item", {
  r0 <- suppressMessages(respondent_burden(exposure_qsf_ov(), exposure_responses()))
  r1 <- suppressMessages(respondent_burden(exposure_qsf_ov(), exposure_responses(),
                                           overrides = c(QID2 = 10)))
  # R1 saw QID2 (22 -> 30); R2 declined consent and never reached it
  expect_equal(r1$points[r1$response_id == "R1"], 30)
  expect_equal(r1$points[r1$response_id == "R2"], r0$points[r0$response_id == "R2"])

  # design points per block follow the override too
  b1 <- suppressMessages(rb_blocks(exposure_qsf_ov(), exposure_responses(),
                                   overrides = c(QID2 = 10)))
  expect_equal(unique(b1$design_points[b1$block_id == "BL2"]), 17)
})

test_that("an override wins over per-respondent words_per_line rescoring", {
  # demo survey: QID1 (BL1, shown to everyone) is descriptive text, 11 points
  # at 12 words per line and 69 at 2. Differing words_per_line rescore it per
  # respondent; an override must hold for all of them.
  responses <- data.frame(ResponseId = c("R_1", "R_2"), Finished = c(1, 1),
                          QID2 = c("2", "2"))
  wpl <- c(2, 12)
  b0 <- suppressMessages(rb_blocks(demo_qsf(), responses, words_per_line = wpl))
  b1 <- suppressMessages(rb_blocks(demo_qsf(), responses, words_per_line = wpl,
                                   overrides = c(QID1 = 5)))
  bl1 <- function(b, id) b$points[b$response_id == id & b$block_id == "BL1"]
  expect_equal(bl1(b0, "R_1") - bl1(b0, "R_2"), 69 - 11)
  expect_equal(bl1(b1, "R_1"), bl1(b1, "R_2"))
  expect_equal(bl1(b1, "R_2"), bl1(b0, "R_2") - 11 + 5)
})

test_that("unknown ids error in every high-level function", {
  q <- exposure_qsf_ov()
  bad <- c(QID999 = 5)
  expect_error(burden_report(q, quiet = TRUE, overrides = bad), "QID999")
  expect_error(path_burden_profile(q, overrides = bad), "QID999")
  expect_error(suppressMessages(respondent_burden(q, exposure_responses(),
                                                  overrides = bad)), "QID999")
})

test_that("validate_times() passes overrides through to respondent burden", {
  obs <- exposure_responses()
  obs$`Duration (in seconds)` <- c(600, 300, 400, 200, 700)
  v0 <- suppressMessages(validate_times(exposure_qsf_ov(), obs, trim = c(0, Inf)))
  v1 <- suppressMessages(validate_times(exposure_qsf_ov(), obs, trim = c(0, Inf),
                                        overrides = c(QID2 = 10)))
  expect_equal(v1$predicted_burden[1], v0$predicted_burden[1] + 8)
})

test_that("path_burden_profile() warns when overrides meet a precomputed engine", {
  q <- exposure_qsf_ov()
  e <- suppressMessages(surveyBurden:::burden_engine(q))
  expect_warning(path_burden_profile(q, engine = e, overrides = c(QID2 = 10)),
                 "engine")
  expect_no_warning(path_burden_profile(q, engine = e))
})
