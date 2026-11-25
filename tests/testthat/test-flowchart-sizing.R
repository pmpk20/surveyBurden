test_that("diagram text scales with the panel and stays inside measured boxes", {
  skip_if_not_installed("ggplot2")
  withr::local_pdf(tempfile(fileext = ".pdf"))
  q <- lp_qsf(list(list(id = paste(rep("Long block name", 4), collapse = " "),
                        qs = list(fg_mc("Q1", 2)))))
  p <- suppressMessages(plot_route_flowchart(q, direction = "TB", include_medians = FALSE))
  lay <- attr(p, "flowchart_layout")
  # Evaluate the same dynamic grob on differently sized panel viewports.
  for (scale in c(0.35, 1, 1.5)) {
    xr <- p$coordinates$limits$x; yr <- p$coordinates$limits$y
    grid::pushViewport(grid::viewport(width = grid::unit(diff(xr) * scale, "mm"),
                                     height = grid::unit(diff(yr) * scale, "mm")))
    g <- grid::gTree(x = rep(.5, nrow(lay$nodes)), y = rep(.5, nrow(lay$nodes)),
      labels = vapply(lay$nodes$lines, paste, "", collapse = "\n"),
      x_span = diff(xr), y_span = diff(yr), font_size = 3, label_box = FALSE,
      cl = "flowchart_text_grob")
    actual <- grid::makeContent(g)
    for (i in seq_len(nrow(lay$nodes))) {
      text <- actual$children[[i]]
      w <- grid::convertWidth(grid::grobWidth(text), "mm", valueOnly = TRUE)
      h <- grid::convertHeight(grid::grobHeight(text), "mm", valueOnly = TRUE)
      expect_lt(w, lay$nodes$w[i] * scale)
      expect_lt(h, lay$nodes$h[i] * scale)
    }
    grid::popViewport()
  }
  build <- ggplot2::ggplot_build(p)
  expect_equal(build$layout$panel_params[[1]]$x.range, p$coordinates$limits$x)
  expect_equal(build$layout$panel_params[[1]]$y.range, p$coordinates$limits$y)
  size <- attr(p, "size_in")
  gt <- ggplot2::ggplotGrob(p)
  fixed <- grid::convertHeight(sum(gt$heights), "in", valueOnly = TRUE)
  expect_equal(unname(size["height"] - fixed), diff(p$coordinates$limits$y) / 25.4)
  for (factor in c(.5, 1)) expect_no_error(ggplot2::ggsave(tempfile(fileext = ".pdf"), p,
    width = size[1] * factor, height = size[2] * factor, limitsize = FALSE))
})

test_that("survey, API-shaped input and retained reports share one routing result", {
  skip_if_not_installed("ggplot2")
  withr::local_pdf(tempfile(fileext = ".pdf"))
  q <- read_qsf(system.file("extdata", "demo_display_logic.qsf", package = "surveyBurden"))
  original <- resolve_flow
  calls <- 0L
  testthat::local_mocked_bindings(resolve_flow = function(...) {
    calls <<- calls + 1L
    original(...)
  }, .package = "surveyBurden")
  p <- suppressMessages(plot_route_flowchart(q))
  expect_equal(calls, 1L)
  report <- attr(p, "burden_report")
  expect_s3_class(report, "burden_report")
  calls <- 0L
  cached <- plot_route_flowchart(report)
  expect_equal(calls, 0L)
  expect_equal(attr(p, "model"), attr(cached, "model"))
  calls <- 0L
  light <- suppressMessages(plot_route_flowchart(q, include_medians = FALSE))
  expect_equal(calls, 1L)
  expect_null(attr(light, "burden_report"))
  expect_equal(attr(light, "model")$edges, attr(p, "model")$edges)
  expect_false(any(grepl("median", unlist(attr(light, "model")$nodes$lines))))
  hidden <- plot_route_flowchart(report, include_medians = FALSE)
  expect_equal(attr(hidden, "model"), attr(light, "model"))
  # fetch_qsf returns qsf_raw; its output is accepted directly through a pipe.
  # A mocked API call avoids network/credentials while testing that contract.
  testthat::local_mocked_bindings(fetch_qsf = function(...) q, .package = "surveyBurden")
  expect_s3_class(suppressMessages(fetch_qsf("SV_example") |> plot_route_flowchart()), "ggplot")
  expect_error(plot_route_flowchart(q, include_medians = NA), "include_medians")
})
