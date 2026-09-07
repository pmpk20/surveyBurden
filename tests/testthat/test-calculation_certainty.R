fx <- function() demo_qsf()

cc <- local({
  v <- NULL
  function() { if (is.null(v)) v <<- calculation_certainty(fx()); v }
})

test_that("calculation_certainty returns the documented structure", {
  x <- cc()
  expect_s3_class(x, "calculation_certainty")
  expect_true(all(c("paths", "branches", "display_logic", "loops", "scores") %in% names(x)))
})

test_that("complete paths split into exactly-resolved and unresolved-condition", {
  p <- cc()$paths
  expect_equal(p$n_full, 2L)
  expect_equal(p$n_exact + p$n_with_unresolved, p$n_full)
  expect_s3_class(p$per_path, "data.frame")
})

test_that("every loop block has a known iteration cap", {
  l <- cc()$loops
  expect_equal(l$n_unknown, 0L)
  expect_equal(l$n_known, 2L)
  expect_setequal(l$bounds$max_iter, c(5L, 3L))
})

test_that("display-logic certainty partitions conditional questions", {
  d <- cc()$display_logic
  expect_gt(d$n_conditional, 0L)
  expect_equal(d$n_exact + d$n_approx, d$n_conditional)
  expect_equal(d$n_exact_components + d$n_approx_components, d$n_components)
  expect_type(d$cross_component_independence, "logical")
})

test_that("item-score certainty tallies every live question by flag", {
  s <- cc()$scores
  expect_true(all(c("auto", "inferred", "manual", "unknown") %in% names(s)))
  expect_equal(sum(unlist(s)), 26L)
})

test_that("branches are listed with a trigger variable", {
  b <- cc()$branches
  expect_s3_class(b, "data.frame")
  expect_true(all(c("flow_id", "trigger") %in% names(b)))
  expect_gt(nrow(b), 0L)
})

test_that("format.calculation_certainty renders the headline sections", {
  out <- format(cc())
  expect_true(any(grepl("Calculation certainty", out)))
  expect_true(any(grepl("Display logic", out)))
  expect_true(any(grepl("Loops", out)))
})

test_that("burden_report embeds and prints calculation certainty", {
  r <- burden_report(fx(), profile = FALSE)
  expect_s3_class(r$certainty, "calculation_certainty")
  out <- format(r)
  expect_true(any(grepl("Calculation certainty", out)))
  expect_true(any(grepl("resolve exactly", out)))
})
