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

test_that("validate_times returns a comparison against observed times", {
  qsf <- read_qsf(demo_qsf())
  v <- validate_times(qsf, varied_fixture())

  expect_true(all(c("n", "observed", "predicted", "ratio", "cor", "r_squared",
                    "implied_points_per_minute", "lm", "predicted_burden") %in% names(v)))
  expect_false("basis" %in% names(v))
  expect_true(is.finite(v$cor) && abs(v$cor) <= 1)
  expect_true(is.finite(v$r_squared) && v$r_squared >= 0 && v$r_squared <= 1)
  expect_equal(v$n, 60L)
  expect_length(v$observed, 5L)
  expect_length(v$predicted_burden, 60L)
  expect_true(is.finite(v$ratio) && v$ratio > 0)
  expect_true(is.finite(v$implied_points_per_minute) && v$implied_points_per_minute > 0)
})

test_that("predicted burden is each respondent's respondent burden", {
  qsf <- read_qsf(demo_qsf())
  obs <- times_fixture()
  v <- validate_times(qsf, obs, finished_only = FALSE)
  rb <- suppressMessages(respondent_burden(qsf, obs))
  expect_equal(v$predicted_burden, rb$points)
  out <- cli::cli_fmt(print(v))
  expect_true(any(grepl("respondent burden", out)))
})

test_that("validate_times reads a CSV path and trims out-of-range times", {
  qsf <- read_qsf(demo_qsf())
  obs <- times_fixture()
  obs$completion_mins <- NULL
  obs$completion_seconds <- c(120, 60 * 25, 60 * 400, 60 * 20)  # 2 and 400 min trimmed
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  utils::write.csv(obs, tmp, row.names = FALSE, na = "")

  v <- validate_times(qsf, tmp, finished_only = FALSE)
  expect_equal(v$n, 2L)
})

test_that("validate_times reads Qualtrics' Duration (in seconds) column directly", {
  qsf <- read_qsf(demo_qsf())
  obs <- times_fixture()
  obs$completion_mins <- NULL
  secs <- c(60 * 20, 60 * 25, 60 * 30, 60 * 35)
  ref  <- validate_times(qsf, cbind(obs, completion_seconds = secs))

  # as named in the export, and as read.csv() mangles it
  d1 <- obs; d1[["Duration (in seconds)"]] <- secs
  d2 <- obs; d2$Duration..in.seconds. <- secs
  expect_equal(validate_times(qsf, d1)$observed, ref$observed)
  expect_equal(validate_times(qsf, d2)$observed, ref$observed)

  # stored as text (e.g. a raw export read without type conversion)
  d3 <- obs; d3[["Duration (in seconds)"]] <- as.character(secs)
  expect_equal(validate_times(qsf, d3)$observed, ref$observed)
})

test_that("validate_times reads a raw Qualtrics CSV export with its header rows", {
  qsf <- read_qsf(demo_qsf())
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  writeLines(c(
    '"ResponseId","Finished","Duration (in seconds)","QID2"',
    '"Response ID","Finished","Duration (in seconds)","Consent"',
    '"{""ImportId"":""_recordId""}","{""ImportId"":""finished""}","{""ImportId"":""duration""}","{""ImportId"":""QID2""}"',
    '"R_1","1","1200","1"',
    '"R_2","1","1500","1"'
  ), tmp)
  expect_message(v <- validate_times(qsf, tmp), "2 Qualtrics header rows")
  expect_equal(v$n, 2L)
})

test_that("validate_times says which duration columns it looks for", {
  qsf <- read_qsf(demo_qsf())
  expect_error(validate_times(qsf, data.frame(minutes = 20)),
               "completion_mins")
})

test_that("validate_times keeps finishers only, unless asked not to", {
  qsf <- read_qsf(demo_qsf())
  obs <- times_fixture()
  expect_equal(validate_times(qsf, obs)$n, 3L)
  expect_equal(validate_times(qsf, obs, finished_only = FALSE)$n, 4L)
})

test_that("respondent order is kept after row filtering", {
  qsf <- read_qsf(demo_qsf())
  obs <- times_fixture()
  all_rows <- validate_times(qsf, obs, finished_only = FALSE)
  fin_rows <- validate_times(qsf, obs)
  expect_equal(fin_rows$predicted_burden, all_rows$predicted_burden[obs$Finished == 1])
})

test_that("a constant prediction gives cor NA without a warning, and prints", {
  qsf <- read_qsf(demo_qsf())
  obs <- times_fixture()[c(1, 1, 1), ]
  obs$ResponseId <- c("A", "B", "C")
  obs$completion_mins <- c(20, 25, 30)
  v <- expect_no_warning(validate_times(qsf, obs))
  expect_true(is.na(v$cor))
  out <- cli::cli_fmt(print(v))
  expect_true(any(grepl("Observed minutes", out)))
  expect_true(any(grepl("same prediction", out)))
})

test_that("respondent_burden() errors propagate", {
  qsf <- read_qsf(demo_qsf())
  obs <- times_fixture()
  obs$ResponseId[2] <- "R_1"   # duplicated id
  expect_error(validate_times(qsf, obs), "unique")
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

test_that("print shows the median-based label and how many rows the trim dropped", {
  qsf <- read_qsf(demo_qsf())
  obs <- rate_fixture(40)
  obs$completion_mins[1:3] <- c(0.1, 0.2, 500)
  v <- validate_times(qsf, obs, trim = c(0.5, 400))
  expect_equal(v$n_trimmed, 3L)
  expect_equal(v$n, 37L)
  out <- paste(cli::cli_fmt(print(v)), collapse = "\n")
  expect_match(out, "median points / median minutes")
  expect_match(out, "3 dropped")
})
