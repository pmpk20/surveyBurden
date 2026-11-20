#' Plot the ex ante burden distribution of each route
#'
#' Draws, for each route through the survey, the distribution of burden across
#' the synthetic responses of [path_burden_profile()]: every modelled
#' combination of display conditions, weighted as in the profile. One row per
#' route. Bars are the share of the route's synthetic responses in each bin of
#' GfS+ points, each bin outlined in black. Every route's tallest bar is drawn
#' at the same height, so the shape of each route can be read, but bar heights
#' are not comparable between routes. The thick black line spans the 25th to
#' 75th percentile, the open circle is the route median and the thin grey line
#' is the route range. The dotted red vertical line is the pooled median of
#' the complete routes, with routes equally weighted, which is the median
#' [burden_report()] reports in `$burden`. The right-hand label gives each
#' route's median.
#'
#' These are model-weighted distributions over synthetic responses, not
#' distributions over respondents (see [path_burden_profile()]). A route whose
#' display logic cannot change its burden has one value. It is drawn as a
#' filled dot with no histogram, and the footer note says so.
#'
#' **Route labels.** Complete routes are numbered 1 to n in `path_id` order and
#' labelled "Route 1", "Route 2", and so on. Routes that end early (when
#' `include_screenouts = TRUE`) are numbered separately and labelled "Ending
#' early 1", and so on. The number in a label is therefore not the `path_id`
#' in `report$paths`, which also counts routes that end early. To match them,
#' use the plot data (`plot_burden_profile(x)$data`). It has one row per drawn
#' route, with its label and its original `path_id` (`NA` for the pooled row).
#' The numbering covers all complete routes, so it does not change when
#' `max_routes` shows only some of them.
#'
#' With more than `max_routes` routes the plot cannot show every route
#' legibly. It then shows the pooled distribution of all routes in the top row
#' and `max_routes` routes spread evenly across the ordering of route medians
#' (so the lightest and heaviest are both included), and says so in a message.
#'
#' If no route is complete, the routes that end early are drawn instead, with
#' a message, and the pooled median line is left out.
#'
#' @param x A [path_burden_profile()] result, or a [burden_report()] object
#'   built with `profile = TRUE` (it keeps the profile it computed).
#' @param include_screenouts If `FALSE` (default) only complete routes are
#'   drawn. If `TRUE`, routes that end early (screen-outs) are drawn too, in
#'   grey and labelled "Ending early k". The pooled median line always uses
#'   complete routes only, as [burden_report()] does.
#' @param max_routes Most routes to draw (default 20). Beyond this, a pooled
#'   row and an evenly spaced selection of routes are shown (see Details).
#'   Use `Inf` to draw every route.
#' @param labels Optional route labels: a character vector named by `path_id`,
#'   or an unnamed vector with one label per row of `x`. Routes without a
#'   label get the numbered labels described in Details.
#' @param binwidth Width of the histogram bins in GfS+ points. `NULL` (default)
#'   uses 10 points, or less when the overall range is under 100 points.
#'
#' @return A `ggplot` object (not printed). Its data has one row per drawn
#'   route, with `path_id`, `label`, `early` and the summary statistics.
#'   Requires the ggplot2 package.
#'
#' @examples
#' \donttest{
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
#'                           package = "surveyBurden")
#'   pbp <- path_burden_profile(read_qsf(qsf_path))
#'   plot_burden_profile(pbp)
#' }
#' }
#'
#' @seealso [path_burden_profile()], [burden_report()]
#' @export
plot_burden_profile <- function(x, include_screenouts = FALSE, max_routes = 20L,
                                labels = NULL, binwidth = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.fn plot_burden_profile} needs the {.pkg ggplot2} package.",
      i = "Install it with {.code install.packages(\"ggplot2\")}."
    ))
  }
  if (!is.numeric(max_routes) || length(max_routes) != 1L || is.na(max_routes) ||
      max_routes < 1) {
    cli::cli_abort("{.arg max_routes} must be a single number of at least 1.")
  }
  if (!is.null(binwidth) && (!is.numeric(binwidth) || length(binwidth) != 1L ||
                             is.na(binwidth) || binwidth <= 0)) {
    cli::cli_abort("{.arg binwidth} must be a single positive number.")
  }

  if (inherits(x, "burden_report")) {
    prof <- attr(x, "path_profile")
    if (is.null(prof)) {
      cli::cli_abort(c(
        "This {.cls burden_report} holds no route profile.",
        i = "Build it with {.code profile = TRUE}, or pass the result of {.fn path_burden_profile}."
      ))
    }
    x <- prof
  }
  if (!is.data.frame(x) ||
      !all(c("path_id", "terminates_early", "profile") %in% names(x))) {
    cli::cli_abort("{.arg x} must be a {.fn path_burden_profile} result or a {.fn burden_report} object.")
  }

  # One entry per route; weights normalised so each route sums to 1.
  # Complete routes are numbered 1..n in path_id order and routes that end
  # early are numbered separately, so labels have no gaps. The numbering is
  # fixed here, before any subsetting, so labels stay stable.
  n_all <- nrow(x)
  early_all <- vapply(x$terminates_early, isTRUE, logical(1))
  num <- integer(n_all)
  num[!early_all] <- rank(x$path_id[!early_all], ties.method = "first")
  num[early_all]  <- rank(x$path_id[early_all], ties.method = "first")
  lab <- ifelse(early_all, paste("Ending early", num), paste("Route", num))
  if (!is.null(labels)) {
    if (!is.null(names(labels))) {
      m <- match(as.character(x$path_id), names(labels))
      lab[!is.na(m)] <- as.character(labels)[m[!is.na(m)]]
    } else if (length(labels) == n_all) {
      lab <- as.character(labels)
    } else {
      cli::cli_abort("{.arg labels} must be named by {.field path_id} or have one entry per row of {.arg x} ({n_all}).")
    }
  }
  routes <- lapply(seq_len(n_all), function(i) {
    d <- x$profile[[i]]
    list(path_id = x$path_id[i], label = lab[i], early = early_all[i],
         burden = d$burden, weight = d$weight / sum(d$weight))
  })
  # draw complete routes first, then those that end early, each in path_id order
  routes <- routes[order(early_all, x$path_id)]
  complete <- !vapply(routes, `[[`, logical(1), "early")

  # pooled over complete routes, routes equally weighted (as burden_report())
  pool <- function(rs) {
    list(burden = unlist(lapply(rs, `[[`, "burden")),
         weight = unlist(lapply(rs, function(r) r$weight / length(rs))))
  }
  pooled <- if (any(complete)) pool(routes[complete]) else NULL

  if (!any(complete) && !isTRUE(include_screenouts)) {
    cli::cli_inform(c(
      "No route is complete, so every route ends early.",
      i = "Drawing the routes that end early."
    ))
    include_screenouts <- TRUE
  }
  shown <- if (isTRUE(include_screenouts)) routes else routes[complete]

  has_pooled_row <- length(shown) > max_routes
  if (has_pooled_row) {
    n_routes <- length(shown)
    med <- vapply(shown, function(r) weighted_quantile(r$burden, r$weight, .5),
                  numeric(1))
    ord <- order(med, seq_along(med))
    pick <- sort(ord[unique(round(seq(1, n_routes, length.out = max_routes)))])
    cli::cli_inform(c(
      "The survey has {n_routes} routes, more than {.arg max_routes} = {max_routes}.",
      i = "Drawing the pooled distribution of all routes and {length(pick)} routes spaced evenly by route median, lightest to heaviest."
    ))
    top <- c(pool(shown), list(path_id = NA_integer_,
                               label = sprintf("All %d routes (pooled)", n_routes),
                               early = FALSE))
    shown <- c(list(top), shown[pick])
  }

  n <- length(shown)
  rows <- do.call(rbind, lapply(seq_len(n), function(i) {
    r <- shown[[i]]
    q <- weighted_quantile(r$burden, r$weight, c(0, .25, .5, .75, 1))
    data.frame(row = n - i + 1, path_id = r$path_id, label = r$label,
               early = r$early, pooled = has_pooled_row && i == 1L,
               single = length(unique(r$burden)) == 1L,
               pmin = q[1], p25 = q[2], med = q[3], p75 = q[4], pmax = q[5],
               stringsAsFactors = FALSE)
  }))
  rows$fill <- ifelse(rows$early, "#BDBDBD", ifelse(rows$pooled, "#4F6D8F", "#6F93B8"))

  all_b <- unlist(lapply(shown, `[[`, "burden"))
  span <- diff(range(all_b))
  if (is.null(binwidth)) {
    binwidth <- if (span >= 100) 10 else if (span == 0) 1 else {
      cand <- c(0.1, 0.2, 0.5, 1, 2, 5, 10)
      cand[which(cand >= span / 10)[1]]
    }
  }

  # Histogram: share of each row's synthetic responses per bin, scaled so
  # every row's tallest bar has the same height. Single-valued rows get a
  # dot instead.
  hist_df <- do.call(rbind, lapply(seq_len(n), function(i) {
    r <- shown[[i]]
    rw <- rows[rows$row == n - i + 1, ]
    if (rw$single) return(NULL)
    # bins of one point or less are centred on the values, so a lone value
    # sits in the middle of its bar rather than on its edge
    off <- if (binwidth <= 1) binwidth / 2 else 0
    bin <- floor((r$burden + off) / binwidth + 1e-9) * binwidth - off
    h <- stats::aggregate(list(share = r$weight), list(bin = bin), sum)
    h$share <- h$share / sum(h$share)
    h$row <- rw$row
    h$fill <- rw$fill
    h$ytop <- h$row - 0.4 + 0.8 * h$share / max(h$share)
    h$xmax <- h$bin + binwidth
    h
  }))
  multi <- rows[!rows$single, ]
  single <- rows[rows$single, ]

  lo <- min(c(hist_df$bin, rows$pmin))
  hi <- max(c(hist_df$xmax, rows$pmax))
  pad <- max(hi - lo, binwidth * 5)
  x_lim <- c(lo - 0.02 * pad, hi + 0.28 * pad)
  rows$lab_x <- hi + 0.03 * pad
  breaks <- pretty(c(lo, hi), n = 6)
  breaks <- breaks[breaks >= lo & breaks <= hi]
  fmt <- function(v) format(round(v, 1), trim = TRUE, drop0trailing = TRUE)
  rows$text <- ifelse(rows$single, sprintf("value %s", fmt(rows$med)),
                      sprintf("median %s", fmt(rows$med)))
  # summary marks sit on the bottom edge of the row; a single value sits mid-row
  rows$y0 <- ifelse(rows$single, rows$row, rows$row - 0.4)
  rows$ylab <- ifelse(rows$single, rows$row, rows$row - 0.15)
  multi <- rows[!rows$single, ]
  single <- rows[rows$single, ]

  col_med <- "#B2182B"
  p <- ggplot2::ggplot(rows)
  if (!is.null(pooled)) {
    pm <- weighted_quantile(pooled$burden, pooled$weight, .5)
    p <- p +
      ggplot2::geom_vline(xintercept = pm, colour = col_med, linetype = "22",
                          linewidth = 0.45) +
      ggplot2::annotate("text", x = pm + 0.01 * pad, y = n + 0.8, hjust = 0,
                        label = sprintf("All complete routes: median %s", fmt(pm)),
                        size = 2.6, colour = col_med)
  }
  if (nrow(multi)) {
    p <- p +
      ggplot2::geom_rect(data = hist_df, colour = "black", linewidth = 0.15,
                         ggplot2::aes(xmin = bin, xmax = xmax, ymin = row - 0.4,
                                      ymax = ytop, fill = fill)) +
      ggplot2::geom_segment(data = multi, colour = "#9AA7B4", linewidth = 0.3,
                            ggplot2::aes(x = pmin, xend = pmax, y = y0, yend = y0)) +
      ggplot2::geom_segment(data = multi, colour = "black", linewidth = 1.1,
                            ggplot2::aes(x = p25, xend = p75, y = y0, yend = y0)) +
      ggplot2::geom_point(data = multi, shape = 21, size = 1.8, fill = "white",
                          colour = "black", stroke = 0.6,
                          ggplot2::aes(x = med, y = y0))
  }
  if (nrow(single)) {
    p <- p +
      ggplot2::geom_point(data = single, shape = 21, size = 2.4, colour = "black",
                          stroke = 0.5, ggplot2::aes(x = med, y = y0, fill = fill))
  }

  # footer: describe only what is drawn
  note <- character(0)
  if (nrow(multi)) {
    note <- c(note, paste0(
      "Bars: share of the route's synthetic responses in each ", fmt(binwidth),
      "-point bin, with each route's tallest bar scaled to the same height. ",
      "Black line: 25th-75th percentile. Open circle: route median. ",
      "Grey line: route range."))
  }
  if (nrow(single)) {
    note <- c(note, paste0(
      "Filled dot: a route with a single burden value, so no histogram is drawn",
      if (nrow(multi)) "." else " (every route shown has one value)."))
  }
  if (any(rows$early)) note <- c(note, "Grey: routes that end early.")
  if (!is.null(pooled)) {
    note <- c(note, "Dotted red line: pooled median of complete routes.")
  }
  caption <- paste(strwrap(paste(note, collapse = " "), width = 115), collapse = "\n")

  p +
    ggplot2::scale_fill_identity() +
    ggplot2::geom_text(data = rows, hjust = 0, size = 2.5, colour = "#444444",
                       ggplot2::aes(x = lab_x, y = ylab, label = text)) +
    ggplot2::scale_y_continuous(breaks = rows$row, labels = rows$label,
                                limits = c(0.45, n + 1.1), expand = c(0, 0)) +
    ggplot2::scale_x_continuous(breaks = breaks, expand = c(0, 0)) +
    ggplot2::coord_cartesian(xlim = x_lim, clip = "off") +
    ggplot2::labs(
      title = "Ex ante burden across synthetic responses, by route",
      x = "GfS+ points for one synthetic response", y = NULL,
      caption = caption) +
    ggplot2::theme_minimal(base_size = 9) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      plot.title.position = "plot", plot.caption.position = "plot",
      plot.caption = ggplot2::element_text(hjust = 0, colour = "#444444", size = 7),
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_line(colour = "#E6E6E6", linewidth = 0.3))
}

utils::globalVariables(c("bin", "xmax", "row", "ytop", "fill", "pmin", "pmax",
                         "p25", "p75", "med", "y0", "lab_x", "ylab", "text"))
