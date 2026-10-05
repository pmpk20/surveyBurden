test_that("validate_times returns a comparison against synthetic observed times", {
  qsf <- read_qsf(demo_qsf())

  # synthetic respondents: a spread of routes and plausible times
  set.seed(1)
  obs <- data.frame(
    completion_mins  = runif(200, 15, 55),
    source           = sample(c("roots", "household"), 200, TRUE, c(.95, .05)),
    n_children       = rbinom(200, 3, 0.3),
    n_cars           = rbinom(200, 2, 0.6),
    n_vans = 0, n_campers = 0,
    loop_other_adults = rbinom(200, 4, 0.4)
  )

  v <- validate_times(qsf, obs)

  expect_true(all(c("n", "observed", "predicted", "ratio", "cor", "r_squared",
                    "implied_points_per_minute", "lm", "predicted_burden") %in% names(v)))
  expect_true(is.finite(v$cor) && abs(v$cor) <= 1)
  expect_true(is.finite(v$r_squared) && v$r_squared >= 0 && v$r_squared <= 1)
  expect_equal(v$n, 200L)
  expect_length(v$observed, 5L)
  expect_length(v$predicted_burden, 200L)
  expect_true(is.finite(v$ratio) && v$ratio > 0)
  expect_true(is.finite(v$implied_points_per_minute) && v$implied_points_per_minute > 0)
})

test_that("validate_times reads a CSV path and trims out-of-range times", {
  qsf <- read_qsf(demo_qsf())
  tmp <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(
    completion_seconds = c(120, 60 * 25, 60 * 400),  # 2 min (trimmed), 25 min, 400 min (trimmed)
    source = "roots", n_children = 0, n_cars = 1, n_vans = 0, n_campers = 0,
    loop_other_adults = 0
  ), tmp, row.names = FALSE)

  v <- validate_times(qsf, tmp)
  expect_equal(v$n, 1L)
})

test_that("validate_times reads Qualtrics' Duration (in seconds) column directly", {
  qsf <- read_qsf(demo_qsf())
  secs <- c(60 * 20, 60 * 25, 60 * 30)
  ref  <- validate_times(qsf, data.frame(completion_seconds = secs))

  # as named in the export, and as read.csv() mangles it
  d1 <- data.frame(`Duration (in seconds)` = secs, check.names = FALSE)
  d2 <- data.frame(Duration..in.seconds. = secs)
  expect_equal(validate_times(qsf, d1)$observed, ref$observed)
  expect_equal(validate_times(qsf, d2)$observed, ref$observed)

  # stored as text (e.g. a raw export read without type conversion)
  d3 <- data.frame(`Duration (in seconds)` = as.character(secs), check.names = FALSE)
  expect_equal(validate_times(qsf, d3)$observed, ref$observed)
})

test_that("validate_times reads a raw Qualtrics CSV export with its header rows", {
  qsf <- read_qsf(demo_qsf())
  tmp <- tempfile(fileext = ".csv")
  writeLines(c(
    '"ResponseId","Finished","Duration (in seconds)"',
    '"Response ID","Finished","Duration (in seconds)"',
    '"{""ImportId"":""_recordId""}","{""ImportId"":""finished""}","{""ImportId"":""duration""}"',
    '"R_1","1","1200"',
    '"R_2","1","1500"'
  ), tmp)
  expect_message(v <- validate_times(qsf, tmp), "2 Qualtrics header rows")
  expect_equal(v$n, 2L)
})

test_that("validate_times says which duration columns it looks for", {
  qsf <- read_qsf(demo_qsf())
  expect_error(validate_times(qsf, data.frame(minutes = 20)),
               "completion_mins")
})

test_that("with answer columns, validate_times uses each respondent's realised burden", {
  qsf  <- read_qsf(demo_qsf())
  cat_ <- parse_qsf(qsf)
  qids <- cat_$question_id[!cat_$in_loop]
  set.seed(2)
  n <- 60
  obs <- data.frame(ResponseId = paste0("R_", seq_len(n)), Finished = "1",
                    completion_mins = runif(n, 10, 40))
  # respondents answer different numbers of questions
  k <- sample(5:length(qids), n, TRUE)
  for (j in seq_along(qids)) obs[[qids[j]]] <- ifelse(j <= k, "1", NA)

  v <- validate_times(qsf, obs)
  expect_identical(v$basis, "realised")
  expect_equal(v$predicted_burden, realised_burden(qsf, obs)$realised_points)
  expect_true(is.finite(v$cor))

  expect_identical(validate_times(qsf, obs, basis = "route")$basis, "route")
})

test_that("validate_times keeps finishers only, unless asked not to", {
  qsf <- read_qsf(demo_qsf())
  obs <- data.frame(completion_mins = c(20, 25, 30, 35), Finished = c("1", "1", "0", "1"))
  expect_equal(validate_times(qsf, obs)$n, 3L)
  expect_equal(validate_times(qsf, obs, finished_only = FALSE)$n, 4L)
})

test_that("a constant prediction gives cor NA without a warning, and prints", {
  qsf <- read_qsf(demo_qsf())
  v <- expect_no_warning(validate_times(qsf, data.frame(completion_mins = c(20, 25, 30))))
  expect_true(is.na(v$cor))
  out <- cli::cli_fmt(print(v))
  expect_true(any(grepl("Observed minutes", out)))
  expect_true(any(grepl("same prediction", out)))
})

# respondents on the bundled demo survey: complete, break-off, screen-out and
# a finisher who leaves displayed questions blank
shown_fixture <- function() {
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

test_that("basis = 'shown' uses each respondent's summed shown points", {
  qsf <- read_qsf(demo_qsf())
  obs <- shown_fixture()
  v <- validate_times(qsf, obs, basis = "shown", finished_only = FALSE)
  expect_identical(v$basis, "shown")
  ex <- suppressMessages(realised_exposure(qsf, obs))
  expected <- vapply(obs$ResponseId,
                     # blocks never reached have NA shown points
                     function(id) sum(ex$shown_points[ex$response_id == id], na.rm = TRUE),
                     numeric(1), USE.NAMES = FALSE)
  expect_equal(v$predicted_burden, expected)
  out <- cli::cli_fmt(print(v))
  expect_true(any(grepl("every item displayed", out)))
})

test_that("shown burden is at least the realised burden for every respondent", {
  qsf <- read_qsf(demo_qsf())
  obs <- shown_fixture()
  shown    <- validate_times(qsf, obs, basis = "shown",    finished_only = FALSE)
  realised <- validate_times(qsf, obs, basis = "realised", finished_only = FALSE)
  expect_true(all(shown$predicted_burden >= realised$predicted_burden))
  expect_true(any(shown$predicted_burden > realised$predicted_burden))
})

test_that("basis = 'shown' keeps respondent order after row filtering", {
  qsf <- read_qsf(demo_qsf())
  obs <- shown_fixture()
  all_rows <- validate_times(qsf, obs, basis = "shown", finished_only = FALSE)
  fin_rows <- validate_times(qsf, obs, basis = "shown")
  expect_equal(fin_rows$predicted_burden, all_rows$predicted_burden[obs$Finished == 1])
})

test_that("basis = 'shown' propagates realised_exposure() errors", {
  qsf <- read_qsf(demo_qsf())
  obs <- shown_fixture()
  obs$ResponseId[2] <- "R_1"   # duplicated id
  expect_error(validate_times(qsf, obs, basis = "shown"), "unique")
})
