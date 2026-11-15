# respondents on the bundled demo survey: complete, break-off, screen-out and
# a finisher who leaves displayed questions blank
times_fixture <- function() {
  data.frame(
    ResponseId = c("R_1", "R_2", "R_3", "R_4"),
    Finished   = c(1, 0, 1, 1),
    completion_mins = c(30, 12, 5, 25),
    QID2 = c("1", "1", "2", "1"), QID3 = c(NA, "1", NA, "1"),
    QID4 = c("2", "3", NA, "2"), QID6 = c("1", "4", NA, "1"),
    QID9 = c("2", NA, NA, NA), QID10 = c("1", NA, NA, "1"),
    `1_QID11` = c("2", NA, NA, "1"), QID19_1 = c("3", NA, NA, NA),
    QID22 = c("3", NA, NA, "2"), QID26 = c("1", NA, NA, "1"),
    check.names = FALSE
  )
}

# finishers who answer different numbers of questions
varied_fixture <- function(n = 60) {
  qsf  <- read_qsf(demo_qsf())
  cat_ <- parse_qsf(qsf)
  qids <- cat_$question_id[!cat_$in_loop]
  set.seed(2)
  obs <- data.frame(ResponseId = paste0("R_", seq_len(n)), Finished = "1",
                    completion_mins = runif(n, 10, 40))
  k <- sample(5:length(qids), n, TRUE)
  for (j in seq_along(qids)) obs[[qids[j]]] <- ifelse(j <= k, "1", NA)
  obs
}


test_that("predicted burden is each respondent's respondent burden", {
  qsf <- read_qsf(demo_qsf())
  obs <- times_fixture()
  v <- validate_times(qsf, obs, finished_only = FALSE)
  rb <- suppressMessages(respondent_burden(qsf, obs))
  expect_equal(v$predicted_burden, rb$points)
  out <- cli::cli_fmt(print(v))
  expect_true(any(grepl("respondent burden", out)))
})





test_that("validate_times keeps finishers only, unless asked not to", {
  qsf <- read_qsf(demo_qsf())
  obs <- times_fixture()
  expect_equal(validate_times(qsf, obs)$n, 3L)
  expect_equal(validate_times(qsf, obs, finished_only = FALSE)$n, 4L)
})




# --- M3: robust headline rate ------------------------------------------------

# finishers whose times follow a true rate of 12 points per minute (small
# noise), with 5% taking ten times as long (left the survey open)
rate_fixture <- function(n = 100) {
  qsf <- read_qsf(demo_qsf())
  obs <- varied_fixture(n)
  pts <- suppressMessages(respondent_burden(qsf, obs))$points
  set.seed(3)
  obs$completion_mins <- pts / 12 * exp(stats::rnorm(n, 0, 0.1))
  slow <- seq_len(n) %% 20 == 0
  obs$completion_mins[slow] <- obs$completion_mins[slow] * 10
  obs
}

test_that("the headline rate is median points over median minutes and resists long durations", {
  qsf <- read_qsf(demo_qsf())
  v <- validate_times(qsf, rate_fixture(), trim = c(0, Inf))
  expect_equal(v$implied_points_per_minute,
               stats::median(v$predicted_burden) / stats::median(v$observed_minutes))
  expect_lt(abs(v$implied_points_per_minute / 12 - 1), 0.10)
  # the through-origin regression is kept, but is pulled down by the 5%
  expect_gt(abs(v$ols_points_per_minute / 12 - 1), 0.10)
  expect_equal(v$ols_points_per_minute, 60 / stats::coef(v$lm)[["pred_pts"]])
})

