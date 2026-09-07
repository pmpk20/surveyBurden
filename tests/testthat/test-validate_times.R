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
