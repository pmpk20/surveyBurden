# Diagram coordinates are millimetres at the suggested export size. Ordinary
# geom_text() keeps a fixed physical font when a diagram is resized, so text
# can overflow its shrinking boxes. Resolve this grob inside the panel
# viewport, where its actual physical scale is known.
flowchart_text_layer <- function(data, label_box = FALSE) {
  geom <- ggplot2::ggproto(NULL, ggplot2::Geom,
    required_aes = c("x", "y", "label"),
    default_aes = ggplot2::aes(),
    draw_key = ggplot2::draw_key_blank,
    extra_params = c("na.rm", "label_box"),
    draw_panel = function(data, panel_params, coord, label_box = FALSE, na.rm = FALSE) {
      xy <- coord$transform(data, panel_params)
      grid::gTree(x = xy$x, y = xy$y, labels = as.character(xy$label),
        x_span = diff(panel_params$x.range), y_span = diff(panel_params$y.range),
        font_size = if (label_box) 2.4 else 3,
        label_box = label_box, cl = "flowchart_text_grob")
    })
  ggplot2::layer(data = data, mapping = ggplot2::aes(x, y, label = text),
    stat = "identity", position = "identity", geom = geom, inherit.aes = FALSE,
    params = list(label_box = label_box, na.rm = FALSE))
}

#' @exportS3Method grid::makeContent
makeContent.flowchart_text_grob <- function(x) {
  scale <- min(grid::convertWidth(grid::unit(1, "npc"), "mm", valueOnly = TRUE) / x$x_span,
               grid::convertHeight(grid::unit(1, "npc"), "mm", valueOnly = TRUE) / x$y_span)
  children <- lapply(seq_along(x$labels), function(i) {
    label <- grid::textGrob(x$labels[i], x = x$x[i], y = x$y[i],
      default.units = "npc", gp = grid::gpar(
        fontsize = x$font_size * 72.27 / 25.4 * scale,
        fontfamily = "sans", lineheight = 0.95, col = "black"))
    if (!x$label_box) return(label)
    grid::grobTree(grid::rectGrob(x = x$x[i], y = x$y[i],
      width = grid::grobWidth(label) + grid::unit(1.2 * scale, "mm"),
      height = grid::grobHeight(label) + grid::unit(0.8 * scale, "mm"),
      gp = grid::gpar(fill = "white", col = NA)), label)
  })
  grid::setChildren(x, do.call(grid::gList, children))
}
