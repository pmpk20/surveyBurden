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




