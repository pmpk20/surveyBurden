# Pull the `points` value for one statistic out of a burden_report or its
# $burden / $population tibble.
bstat <- function(x, s) {
  tbl <- if (inherits(x, "burden_report")) x$burden else x
  tbl_points <- tbl$points[match(s, as.character(tbl$statistic))]
  tbl_points
}
