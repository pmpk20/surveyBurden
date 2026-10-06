# Pull the `points` value for one statistic out of a burden_report or its
# $burden / $respondents tibble.
bstat <- function(x, s) {
  tbl <- if (inherits(x, "burden_report")) x$burden else x
  tbl_points <- tbl$points[match(s, as.character(tbl$statistic))]
  tbl_points
}

# Block-level respondent burden, the form most walk tests inspect.
rb_blocks <- function(...) respondent_burden(..., by = "block")
