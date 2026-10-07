test_that("condition-state limit propagates through public calculations", {
  q <- read_qsf(demo_qsf())
  low <- burden_report(q, max_condition_states = 1, quiet = TRUE)
  high <- burden_report(q, max_condition_states = 100000, quiet = TRUE)
  expect_equal(low$certainty$display_logic$max_condition_states, 1)
  expect_equal(high$certainty$display_logic$max_condition_states, 100000)
  expect_gt(low$certainty$display_logic$n_approx, high$certainty$display_logic$n_approx)
  expect_equal(high$certainty$display_logic$n_approx, 0)
  expect_equal(calculation_certainty(q, max_condition_states = 1), low$certainty)
  expect_equal(path_burden_profile(q, max_condition_states = 1)$burden_median,
               low$paths$burden_median)
  expect_equal(path_burden_profile(q, max_condition_states = 100000)$burden_median,
               high$paths$burden_median)
  expect_equal(calculation_certainty(q)$display_logic$max_condition_states, 10000)
})

test_that("public condition-state limits reject invalid values", {
  for (fun in list(burden_report, path_burden_profile, calculation_certainty)) {
    for (value in list(0, -1, 1.5, NA_real_, Inf, c(1, 2), "10000", NULL)) {
      expect_error(fun(NULL, max_condition_states = value), "max_condition_states")
    }
  }
})
