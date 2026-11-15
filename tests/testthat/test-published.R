# Figures for the JSS paper's application (Section 6), from surveyBurden 0.3.0.
# The survey file is private, so this runs only where it is available. If a
# change moves any of these numbers, the paper must be updated to match.
test_that("the paper's application survey gives the published figures", {
  skip_on_cran()
  qsf_file <- file.path(
    "C:/Users/earpkin/OneDrive - University of Leeds/Careers/surveyBurden",
    "misc/INFUZE_CORE_SURVEY_April_2026_Part_A (3).qsf"
  )
  skip_if_not(file.exists(qsf_file), "Application survey QSF not available")
  r <- suppressMessages(burden_report(qsf_file, quiet = TRUE))
  expect_equal(r$survey$n_questions, 211L)
  expect_equal(r$survey$n_blocks, 23L)
  expect_equal(sum(r$blocks$gfs_points), 952.5)
  expect_equal(nrow(r$paths), 52L)
  cp <- r$paths[r$paths$status == "complete", ]
  expect_equal(nrow(cp), 24L)
  expect_equal(stats::median(cp$burden_median), 779.5)
  expect_equal(min(cp$burden_min), 492.5)
  expect_equal(max(cp$burden_max), 1319.5)
})
