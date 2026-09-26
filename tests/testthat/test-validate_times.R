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
