flowchart_wrap <- function(lines, width) {
  unlist(lapply(lines, function(l) if (nchar(l) <= width) l else
    strwrap(l, width = width)), use.names = FALSE)
}

layout_flowchart <- function(model, direction = c("LR", "TB"), wrap = 24) {
  direction <- match.arg(direction)
  nd <- model$nodes; ed <- model$edges
  nd$lines <- lapply(nd$lines, flowchart_wrap, width = wrap)
  # Measure the actual text, in millimetres, using the same font/size as
  # the drawing. This avoids character-count estimates for proportional fonts.
  measure <- function(lines) {
    grob <- grid::textGrob(paste(lines, collapse = "\n"),
                           gp = grid::gpar(fontsize = 3 * 72.27 / 25.4,
                                           fontfamily = "sans", lineheight = 0.95))
    c(w = grid::convertWidth(grid::grobWidth(grob), "mm", valueOnly = TRUE),
      h = grid::convertHeight(grid::grobHeight(grob), "mm", valueOnly = TRUE))
  }
  size <- t(vapply(nd$lines, measure, c(w = 0, h = 0)))
  isd <- nd$type == "branch"
  nd$w <- ifelse(isd, 2 * size[, "w"] + 8, size[, "w"] + 8)
  nd$h <- ifelse(isd, 2 * size[, "h"] + 6, size[, "h"] + 6)
  # layers
  L <- rep(1L, nrow(nd))
  repeat {
    new <- L
    for (k in seq_len(nrow(ed))) new[ed$to[k]] <- max(new[ed$to[k]], L[ed$from[k]] + 1L)
    if (identical(new, L)) break
    L <- new
  }
  nd$layer <- L
  # dummy nodes for long edges
  nodes <- data.frame(key = paste0("n", nd$id), layer = nd$layer,
                      w = nd$w, h = nd$h, real = TRUE, stringsAsFactors = FALSE)
  chain <- vector("list", nrow(ed))
  for (k in seq_len(nrow(ed))) {
    u <- ed$from[k]; v <- ed$to[k]; ks <- paste0("n", u)
    if (L[v] - L[u] > 1L) for (l in (L[u] + 1L):(L[v] - 1L)) {
      key <- sprintf("d%d_%d", k, l)
      nodes <- rbind(nodes, data.frame(key = key, layer = l, w = 0.5, h = 0.5,
                                       real = FALSE, stringsAsFactors = FALSE))
      ks <- c(ks, key)
    }
    chain[[k]] <- c(ks, paste0("n", v))
  }
  seg <- do.call(rbind, lapply(chain, function(ch) data.frame(a = head(ch, -1), b = ch[-1])))
  nodes$ord <- ave(seq_len(nrow(nodes)), nodes$layer, FUN = seq_along)
  for (sweep in 1:6) {
    down <- sweep %% 2 == 1
    for (l in sort(unique(nodes$layer), decreasing = !down)) {
      here <- which(nodes$layer == l)
      nb <- vapply(here, function(i) {
        key <- nodes$key[i]
        o <- if (down) seg$a[seg$b == key] else seg$b[seg$a == key]
        if (!length(o)) NA_real_ else mean(nodes$ord[match(o, nodes$key)])
      }, 0)
      nb[is.na(nb)] <- nodes$ord[here][is.na(nb)]
      nodes$ord[here] <- rank(nb, ties.method = "first")
    }
  }
  # coordinates in (a = along layers, b = across)
  ext_a <- if (direction == "LR") nodes$w else nodes$h
  ext_b <- if (direction == "LR") nodes$h else nodes$w
  gap_a <- 10; gap_b <- 10
  lay <- sort(unique(nodes$layer))
  la <- vapply(lay, function(l) max(ext_a[nodes$layer == l]), 0)
  centre_a <- cumsum(la + gap_a) - la / 2
  nodes$a <- centre_a[match(nodes$layer, lay)]
  nodes$b <- 0
  for (l in lay) {
    here <- which(nodes$layer == l); here <- here[order(nodes$ord[here])]
    tot <- sum(ext_b[here]) + gap_b * (length(here) - 1L)
    pos <- cumsum(ext_b[here] + gap_b) - ext_b[here] / 2 - tot / 2
    nodes$b[here] <- pos
  }
  lane_base <- max(nodes$b + ext_b / 2) + 10
  long <- which(lengths(chain) > 2L)
  lane_end <- numeric()
  for (k in long) {
    first <- L[ed$from[k]]; last <- L[ed$to[k]]
    free <- which(lane_end < first)
    lane <- if (length(free)) free[1] else length(lane_end) + 1L
    lane_end[lane] <- last
    nodes$b[match(chain[[k]][-c(1, length(chain[[k]]))], nodes$key)] <- lane_base + lane * 8
  }
  sgn <- if (direction == "LR") -1 else 1           # LR: first on top
  to_xy <- function(a, b) if (direction == "LR") list(x = a, y = sgn * b) else list(x = b, y = -a)
  xy <- to_xy(nodes$a, nodes$b); nodes$x <- xy$x; nodes$y <- xy$y
  nodes$ext_a <- ext_a
  # edge polylines through (dummy) nodes, elbows in the gap between layers
  polys <- lapply(seq_len(nrow(ed)), function(k) {
    ch <- chain[[k]]; pts <- NULL; u <- ed$from[k]; v <- ed$to[k]
    for (s in seq_len(length(ch) - 1L)) {
      p <- nodes[match(ch[s], nodes$key), ]; q <- nodes[match(ch[s + 1L], nodes$key), ]
      a0 <- p$a + p$ext_a / 2; a1 <- q$a - q$ext_a / 2
      incoming <- which(ed$to == v)
      previous_b <- vapply(incoming, function(e) {
        cc <- chain[[e]]
        nodes$b[match(cc[length(cc) - 1L], nodes$key)]
      }, 0)
      rank_in <- match(k, incoming[order(previous_b)])
      count_in <- sum(ed$to == v)
      rank_out <- match(k, which(ed$from == u))
      count_out <- sum(ed$from == u)
      gap0 <- p$a + la[match(p$layer, lay)] / 2
      gap1 <- q$a - la[match(q$layer, lay)] / 2
      am <- gap0 + (gap1 - gap0) * (0.25 + 0.5 * rank_out / (count_out + 1))
      if (s == length(ch) - 1L && count_in > 1 && nd$type[v] != "branch") {
        q$b <- q$b + (rank_in / (count_in + 1) - 0.5) *
          (if (direction == "LR") nd$h[v] else nd$w[v]) * 0.7
      }
      seg_pts <- rbind(c(a0, p$b), c(am, p$b), c(am, q$b), c(a1, q$b))
      if (!p$real) seg_pts <- rbind(c(p$a, p$b), seg_pts)
      pts <- rbind(pts, seg_pts)
    }
    xyk <- to_xy(pts[, 1], pts[, 2])
    data.frame(edge = k, x = xyk$x, y = xyk$y, n_routes = ed$n_routes[k], label = ed$label[k])
  })
  list(nodes = cbind(nd[, c("id", "type", "w", "h", "layer")],
                     x = nodes$x[match(paste0("n", nd$id), nodes$key)],
                     y = nodes$y[match(paste0("n", nd$id), nodes$key)],
                     lines = I(nd$lines)),
       polys = polys, edges = ed, direction = direction)
}


#' Draw the block-level routes through a Qualtrics survey
#'
#' Blocks show their names and GfS+ points, diamonds show branch conditions,
#' and end boxes show route counts and the median of their route medians
#' (each structural route counts equally). Line widths count structural
#' routes, not respondents or probabilities. Randomiser arms show selections,
#' not their random temporal order. Within-block display logic is not drawn.
#' Loop labels give maximum repetition; repetition is not an extra route.
#' Unsupported conditions are marked as untranslated, with raw operands.
#'
#' @param x A QSF filename, a [read_qsf()] result or a [burden_report()].
#'   Reports retain the survey flow and enumerated routes, including when
#'   built with `profile = FALSE`.
#' @param direction One of `"auto"`, `"LR"` (left to right) or `"TB"`
#'   (top to bottom). Auto uses TB for more than nine boxes.
#' @param collapse_ends Combine screen-outs into one box.
#' @param merge_chains Combine consecutive blocks into one box. Loop blocks
#'   stay separate. Use FALSE to inspect individual blocks.
#' @param highlight_route Optional original route identifier (`path_id`).
#' @param title Optional plot title, wrapped at word boundaries.
#' @param wrap Approximate characters per line, at least eight.
#' @param max_routes Enumeration cap when `x` is a survey. If exceeded, the
#'   structural flow is drawn with uniform lines and no route counts or medians.
#'   A report uses its retained enumeration and scoring settings.
#' @param include_medians Calculate and show route burden medians (default
#'   TRUE). FALSE skips the full burden report when a survey is supplied:
#'   block points and route counts are still shown. With a report, FALSE
#'   simply hides its medians and preserves its scoring settings.
#' @return A ggplot object. Attributes `model`, `flowchart_layout` and `size_in` hold
#'   the graph, connector geometry and suggested export dimensions in inches.
#'   Requires ggplot2. For large surveys use LR, chain merging and a larger
#'   export size rather than shrinking text to fit a page.
#'   Text scales with its boxes when the plot is resized. The `burden_report`
#'   attribute retains a report calculated for this plot, for fast redraws.
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   f <- system.file("extdata", "demo_simple_linear.qsf", package = "surveyBurden")
#'   plot_route_flowchart(f)
#'   plot_route_flowchart(f, include_medians = FALSE)
#' }
#' \dontrun{
#' # The API-to-chart workflow needs no intermediate report:
#' fetch_qsf("SV_xxxxxxxxxxxxxxx") |> plot_route_flowchart()
#' }
#' @seealso [plot_burden_profile()], [burden_report()], [resolve_flow()]
#' @export
plot_route_flowchart <- function(x, direction = c("auto", "LR", "TB"),
                                 collapse_ends = TRUE, merge_chains = TRUE,
                                 highlight_route = NULL, title = NULL, wrap = 24,
                                 max_routes = 10000L, include_medians = TRUE) {
  if (!requireNamespace("ggplot2", quietly = TRUE))
    cli::cli_abort("{.fn plot_route_flowchart} needs the {.pkg ggplot2} package.")
  direction <- match.arg(direction)
  if (!is.logical(include_medians) || length(include_medians) != 1L || is.na(include_medians))
    cli::cli_abort("{.arg include_medians} must be TRUE or FALSE.")
  if (!is.numeric(wrap) || length(wrap) != 1L || is.na(wrap) || wrap < 8 || !is.finite(wrap))
    cli::cli_abort("{.arg wrap} must be a finite number of at least 8 characters.")
  validate_condition_states(max_routes)
  if (!is.logical(collapse_ends) || length(collapse_ends) != 1L || is.na(collapse_ends) ||
      !is.logical(merge_chains) || length(merge_chains) != 1L || is.na(merge_chains))
    cli::cli_abort("{.arg collapse_ends} and {.arg merge_chains} must each be TRUE or FALSE.")
  report <- if (inherits(x, "burden_report")) x else NULL
  if (!is.null(report)) {
    context <- attr(report, "route_flowchart")
    if (is.null(context)) cli::cli_abort("This report has no flow context; rebuild it with burden_report().")
    qsf <- context$qsf; routes <- context$routes
  } else {
    qsf <- if (is.character(x)) read_qsf(x) else x
    if (!inherits(qsf, "qsf_raw")) cli::cli_abort("{.arg x} must be a QSF filename, qsf_raw or burden_report.")
    if (include_medians) {
      # The report already resolves routes. Reuse them instead of enumerating
      # the flow once here and a second time inside burden_report(). Certainty
      # diagnostics are not used by this chart.
      report <- tryCatch(suppressMessages(burden_report(qsf, max_paths = max_routes,
                                                       certainty = FALSE, quiet = TRUE)),
        surveyBurden_route_cap = function(e) NULL)
      routes <- if (is.null(report)) NULL else attr(report, "route_flowchart")$routes
    } else routes <- tryCatch(resolve_flow(qsf, max_paths = max_routes),
                               surveyBurden_route_cap = function(e) NULL)
    if (is.null(routes)) {
      cli::cli_warn("Route cap exceeded; drawing the flow without route counts or route medians.")
    }
  }
  if (!is.null(highlight_route) && (length(highlight_route) != 1L ||
      is.na(highlight_route) || is.null(routes) || !highlight_route %in% routes$path_id))
    cli::cli_abort("{.arg highlight_route} must identify one enumerated route.")
  model <- flow_graph(qsf, routes, report, collapse_ends, merge_chains, include_medians)
  if (direction == "auto") direction <- if (nrow(model$nodes) > 9) "TB" else "LR"
  lay <- layout_flowchart(model, direction, wrap = wrap)
  nd <- lay$nodes
  fills <- c(block = "#DCE9F5", branch = "#FDE9B8", rand = "#E6D9F0", join = "#E6D9F0", start = "#EEEEEE",
             end_ok = "#CFEBD6", end_early = "#F6D0CB")
  edge_col <- "#555555"
  # nodes -> shapes
  rects <- nd[nd$type != "branch", ]
  dia <- nd[nd$type == "branch", ]
  dpoly <- if (nrow(dia)) do.call(rbind, lapply(seq_len(nrow(dia)), function(i) data.frame(
    id = dia$id[i], x = dia$x[i] + c(-1, 0, 1, 0) * dia$w[i] / 2,
    y = dia$y[i] + c(0, 1, 0, -1) * dia$h[i] / 2, type = "branch"))) else NULL
  loop_nodes <- which(!is.na(model$nodes$loop_max))
  loops <- if (length(loop_nodes)) do.call(rbind, lapply(loop_nodes, function(i) {
    z <- nd[i, ]
    if (direction == "TB") data.frame(id = i,
      x = z$x + c(z$w / 2, z$w / 2 + 6, z$w / 2 + 6, z$w / 2),
      y = z$y + c(-z$h / 4, -z$h / 4, z$h / 4, z$h / 4))
    else data.frame(id = i,
      x = z$x + c(z$w / 4, z$w / 4, -z$w / 4, -z$w / 4),
      y = z$y + c(z$h / 2, z$h / 2 + 6, z$h / 2 + 6, z$h / 2))
  })) else NULL
  # edges
  ep <- do.call(rbind, lay$polys)
  nmax <- max(1, ep$n_routes, na.rm = TRUE)
  ep$lw <- ifelse(is.na(ep$n_routes), 0.6, 0.35 + 1.6 * ep$n_routes / nmax)
  ep$used <- is.na(ep$n_routes) | ep$n_routes > 0
  ep$hl <- FALSE
  if (!is.null(highlight_route)) {
    inr <- vapply(lay$edges$route_ids, function(r) highlight_route %in% r, NA)
    ep$hl <- inr[ep$edge]
  }
  ep$col <- ifelse(ep$hl, "#D55E00", ifelse(ep$used, edge_col, "#BBBBBB"))
  # edge labels on branch out-edges
  lab <- do.call(rbind, lapply(lay$polys, function(p) {
    if (!nzchar(p$label[1])) return(NULL)
    data.frame(x = (p$x[3] + p$x[4]) / 2, y = (p$y[3] + p$y[4]) / 2, text = if (is.na(p$n_routes[1])) p$label[1] else sprintf("%s (%d)", p$label[1], p$n_routes[1]))
  }))
  txt <- do.call(rbind, lapply(seq_len(nrow(nd)), function(i) data.frame(
    x = nd$x[i], y = nd$y[i], text = paste(nd$lines[[i]], collapse = "\n"), type = nd$type[i])))

  # Fit the canvas to the entire drawing, including bypasses, loop arrows and
  # connector labels. Remove coord_fixed()'s default five-percent expansion,
  # which becomes several inches of whitespace on a tall survey.
  xr <- range(c(nd$x - nd$w / 2, nd$x + nd$w / 2, ep$x, loops$x))
  yr <- range(c(nd$y - nd$h / 2, nd$y + nd$h / 2, ep$y, loops$y))
  if (!is.null(lab)) for (i in seq_len(nrow(lab))) {
    g <- grid::textGrob(lab$text[i], gp = grid::gpar(fontsize = 2.4 * 72.27 / 25.4))
    w <- grid::convertWidth(grid::grobWidth(g), "mm", valueOnly = TRUE) + 1.2
    h <- grid::convertHeight(grid::grobHeight(g), "mm", valueOnly = TRUE) + 0.8
    xr <- range(xr, lab$x[i] + c(-w, w) / 2)
    yr <- range(yr, lab$y[i] + c(-h, h) / 2)
  }
  xr <- xr + c(-2, 2); yr <- yr + c(-2, 2)
  export_width <- max(4, diff(xr) / 25.4 + 8 / 25.4)
  title_lines <- if (is.null(title)) NULL else paste(strwrap(title,
    width = min(70, floor((export_width - 8 / 25.4) * 12))), collapse = "\n")
  caption_wrap <- min(90, floor((export_width - 8 / 25.4) * 20))

  p <- ggplot2::ggplot() +
    ggplot2::geom_path(data = ep, ggplot2::aes(x, y, group = edge, colour = col, linewidth = lw),
                       arrow = grid::arrow(length = grid::unit(0.09, "in"), type = "closed"),
                       lineend = "round", linejoin = "round") +
    ggplot2::scale_colour_identity() + ggplot2::scale_linewidth_identity() +
    ggplot2::geom_rect(data = rects, ggplot2::aes(xmin = x - w / 2, xmax = x + w / 2,
                       ymin = y - h / 2, ymax = y + h / 2, fill = type),
                       colour = "#444444", linewidth = 0.3) +
    { if (!is.null(dpoly)) ggplot2::geom_polygon(data = dpoly, ggplot2::aes(x, y, group = id, fill = type),
                                                 colour = "#444444", linewidth = 0.3) } +
    ggplot2::scale_fill_manual(values = fills, guide = "none") +
    { if (!is.null(lab)) flowchart_text_layer(lab, label_box = TRUE) } +
    flowchart_text_layer(txt) +
    { if (!is.null(loops)) ggplot2::geom_path(data = loops,
        ggplot2::aes(x, y, group = id), linewidth = 0.4, linetype = "dashed",
        arrow = grid::arrow(length = grid::unit(0.07, "in"), type = "closed")) } +
    ggplot2::coord_fixed(xlim = xr, ylim = yr, expand = FALSE, clip = "off") +
    ggplot2::labs(title = title_lines,
      caption = paste(strwrap(paste0("Boxes: blocks (figures are GfS+ points). Diamonds: branch points. ",
                       if (is.na(model$n_routes)) "Route counts unavailable" else
                         "Line width: number of structural routes using the connection",
                       if (!is.null(highlight_route)) sprintf("; orange: route %s", highlight_route) else "",
                       ". Counts in brackets are routes, not respondent probabilities. ",
                       "Randomiser arms show selections, not temporal order. ",
                       if (!include_medians) "Route medians omitted. " else "",
                       "Dashed arrows mark loops. Within-block display logic is not drawn."), width = caption_wrap), collapse = "
")) +
    ggplot2::theme_void(base_size = 10) +
    ggplot2::theme(plot.caption = ggplot2::element_text(size = 7, hjust = 0, colour = "#444444"),
                   plot.title = ggplot2::element_text(face = "bold", size = 11),
                   plot.title.position = "plot", plot.caption.position = "plot",
                   plot.margin = ggplot2::margin(4, 4, 4, 4, unit = "mm"),
                   plot.background = ggplot2::element_rect(fill = "white", colour = NA))
  # Titles/captions/margins have physical sizes; the panel's null units
  # contribute zero here. Give the panel its exact native millimetres.
  table <- ggplot2::ggplotGrob(p)
  fixed_w <- grid::convertWidth(sum(table$widths), "in", valueOnly = TRUE)
  fixed_h <- grid::convertHeight(sum(table$heights), "in", valueOnly = TRUE)
  attr(p, "size_in") <- c(width = max(4, diff(xr) / 25.4 + fixed_w),
                          height = diff(yr) / 25.4 + fixed_h)
  attr(p, "model") <- model
  attr(p, "flowchart_layout") <- lay
  attr(p, "burden_report") <- report
  p
}


utils::globalVariables(c("x", "y", "edge", "col", "lw", "w", "h", "type", "id", "text"))
