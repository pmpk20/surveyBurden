# Profile with one value per route: route i has burden 100 + i, route 1 early.
toy_profile <- function(n, early = integer()) {
  tibble::tibble(
    path_id = seq_len(n),
    terminates_early = seq_len(n) %in% early,
    profile = lapply(seq_len(n), function(i)
      tibble::tibble(burden = 100 + i + c(0, 4), weight = c(3, 1)))
  )
}
pooled_line <- function(p) {
  for (l in p$layers) if (inherits(l$geom, "GeomVline")) return(l$data$xintercept %||% l$aes_params$xintercept)
}
# labels from the top row down
row_labels <- function(p) ggplot2::ggplot_build(p)$layout$panel_params[[1]]$y$get_labels()

test_that("every bundled demo survey gives a ggplot whose pooled line is the report median", {
  skip_if_not_installed("ggplot2")
  for (f in c("demo_simple_linear", "demo_display_logic", "demo_travel_survey",
              "demo_large_branching")) {
    qsf <- system.file("extdata", paste0(f, ".qsf"), package = "surveyBurden",
                       mustWork = TRUE)
    r <- burden_report(qsf, quiet = TRUE)
    p <- suppressMessages(plot_burden_profile(r))
    expect_s3_class(p, "ggplot")
    med <- r$burden$points[r$burden$statistic == "median"]
    expect_equal(pooled_line(p), med, info = f)
  }
})

test_that("a profile result and a report draw the same plot data", {
  skip_if_not_installed("ggplot2")
  q <- read_qsf(demo_qsf())
  p1 <- plot_burden_profile(path_burden_profile(q))
  p2 <- plot_burden_profile(burden_report(q, quiet = TRUE))
  expect_equal(row_labels(p1), row_labels(p2))
  expect_equal(pooled_line(p1), pooled_line(p2))
  r0 <- burden_report(q, profile = FALSE, quiet = TRUE)
  expect_error(plot_burden_profile(r0), "no structural profile")
})

test_that("max_routes keeps a pooled row and an even spread, and says so", {
  skip_if_not_installed("ggplot2")
  x <- toy_profile(30)
  expect_message(p <- plot_burden_profile(x, max_routes = 5), "30 routes")
  lab <- row_labels(p)
  expect_length(lab, 6)
  expect_equal(lab[1], "All 30 routes (pooled)")
  expect_setequal(lab[c(2, 6)], c("Route 1", "Route 30"))
  expect_silent(plot_burden_profile(x, max_routes = Inf))
  expect_length(row_labels(plot_burden_profile(x, max_routes = Inf)), 30)
})

test_that("screen-outs are left out by default and marked when included", {
  skip_if_not_installed("ggplot2")
  x <- toy_profile(3, early = 2)
  expect_equal(row_labels(plot_burden_profile(x)), c("Route 1", "Route 3"))
  p <- plot_burden_profile(x, include_screenouts = TRUE)
  expect_true("Route 2 (screen-out)" %in% row_labels(p))
  # the pooled line still uses complete routes only
  expect_equal(pooled_line(p), pooled_line(plot_burden_profile(x)))
})

test_that("a single route and single-valued routes plot, with custom labels", {
  skip_if_not_installed("ggplot2")
  x <- toy_profile(1)
  x$profile[[1]] <- tibble::tibble(burden = 250, weight = 1)
  p <- plot_burden_profile(x, labels = c(`1` = "Only route"))
  expect_equal(row_labels(p), "Only route")
  expect_equal(pooled_line(p), 250)
  expect_error(plot_burden_profile(x, labels = c("a", "b")), "labels")
})

test_that("binwidth is 10 points for wide ranges and smaller for narrow ones (range 5 gives 0.5)", {
  skip_if_not_installed("ggplot2")
  wide <- toy_profile(1)
  wide$profile[[1]] <- tibble::tibble(burden = c(100, 300), weight = c(1, 1))
  b <- function(p) {
    i <- which(vapply(p$layers, function(l) inherits(l$geom, "GeomRect"), logical(1)))
    d <- ggplot2::layer_data(p, i)
    d$xmax[1] - d$xmin[1]
  }
  p <- plot_burden_profile(wide)
  expect_equal(b(p), 10)
  expect_equal(b(plot_burden_profile(toy_profile(2))), 0.5)
  expect_equal(b(plot_burden_profile(wide, binwidth = 25)), 25)
})
