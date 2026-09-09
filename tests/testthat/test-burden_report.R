fx <- function() demo_qsf()

report_naive <- local({
  v <- NULL
  function() { if (is.null(v)) v <<- burden_report(fx(), profile = FALSE, certainty = FALSE); v }
})
report_full <- local({
  v <- NULL
  function() { if (is.null(v)) v <<- burden_report(fx(), certainty = FALSE); v }
})

test_that("burden_report accepts a path or a qsf_raw and returns a burden_report", {
  r1 <- report_naive()
  r2 <- burden_report(read_qsf(fx()), profile = FALSE, certainty = FALSE)
  expect_s3_class(r1, "burden_report")
  expect_equal(r1$instrument$n_questions, r2$instrument$n_questions)
})

test_that("the object exposes exactly the documented components", {
  r <- report_full()
  expect_setequal(
    names(r),
    c("instrument", "burden", "blocks", "items", "paths",
      "readability", "certainty", "warnings")
  )
  expect_false("top_items" %in% names(r))
  expect_false("summary" %in% names(r))
  expect_null(r$population)
})

test_that("scalars live on attributes, not components", {
  r <- report_full()
  expect_equal(attr(r, "points_per_minute"), 12)
  expect_equal(attr(r, "rare_threshold"), 1500)
  expect_equal(attr(r, "benchmark"), list(median_points = 399, n_waves = 79L))
  expect_true(attr(r, "profile_used"))
})

test_that("$instrument is a one-row tibble with the structural counts", {
  r <- report_full()
  expect_s3_class(r$instrument, "tbl_df")
  expect_equal(nrow(r$instrument), 1L)
  expect_equal(r$instrument$n_questions, 26L)
  expect_equal(r$instrument$n_blocks, 12L)
  expect_equal(r$instrument$n_branches, 3L)
  expect_equal(r$instrument$n_loop_blocks, 2L)
  expect_equal(r$instrument$n_end_points, 2L)
  expect_equal(r$instrument$n_paths, 4L)
  expect_equal(r$instrument$n_complete_paths, 2L)
  expect_equal(r$instrument$n_screenout_paths, 2L)
})

test_that("$burden is a 5-row tibble; minutes and index are derived", {
  r <- report_full()
  expect_s3_class(r$burden, "tbl_df")
  expect_equal(as.character(r$burden$statistic),
               c("min", "p25", "median", "p75", "max"))
  expect_equal(r$burden$minutes, r$burden$points / 12)
  expect_equal(r$burden$index, r$burden$points / 1500)
  expect_equal(attr(r$burden, "basis"), "structural")
})

test_that("$burden matches the pre-refactor structural range (value parity)", {
  r <- report_full()
  expect_equal(bstat(r, "min"), 106)
  expect_equal(bstat(r, "p25"), 117)
  expect_equal(bstat(r, "median"), 123)
  expect_equal(bstat(r, "p75"), 129)
  expect_equal(bstat(r, "max"), 143)
})

test_that("profile = FALSE gives a naive min/max only and says so", {
  r <- report_naive()
  expect_equal(attr(r$burden, "basis"), "naive")
  expect_equal(bstat(r, "min"), 103)
  expect_equal(bstat(r, "max"), 145)
  expect_true(is.na(bstat(r, "median")))
  w <- paste(r$warnings, collapse = " | ")
  expect_match(w, "not checked|fast estimate", ignore.case = TRUE)
})

test_that("the achievable minimum is at or above the naive floor", {
  expect_gte(bstat(report_full(), "min"), bstat(report_naive(), "min"))
})

test_that("rare_threshold rescales the index", {
  r <- burden_report(fx(), rare_threshold = 750, certainty = FALSE)
  expect_equal(r$burden$index, r$burden$points / 750)
  expect_equal(attr(r, "rare_threshold"), 750)
})

test_that("$blocks lists every block once, in survey order, shares sum to 1", {
  r <- report_full()
  b <- r$blocks
  expect_equal(nrow(b), r$instrument$n_blocks)
  expect_equal(b$flow_order, sort(b$flow_order))
  expect_equal(sum(b$share), 1, tolerance = 1e-6)
  expect_true(all(c("block_id", "block_name", "n_questions", "gfs_points", "share") %in% names(b)))
})

test_that("$items is the full score_burden output, one row per live question", {
  r <- report_full()
  expect_s3_class(r$items, "tbl_df")
  expect_equal(nrow(r$items), r$instrument$n_questions)
  expect_true(all(c("question_id", "question_text", "std_type", "gfs_points",
                    "score_flag", "score_basis", "block_name") %in% names(r$items)))
  expect_equal(names(r$items)[1:5],
               c("question_id", "block_id", "block_name", "question_text", "std_type"))
  expect_true(all(nzchar(r$items$score_basis)))
})

test_that("$paths has one row per structural path with a status factor", {
  r <- report_full()
  p <- r$paths
  expect_equal(nrow(p), r$instrument$n_paths)
  expect_setequal(as.character(unique(p$status)), c("complete", "screen_out"))
  expect_equal(sum(p$status == "complete"), 2L)
  expect_true(all(p$burden_floor <= p$burden_ceiling))
  expect_false(anyNA(p$burden_median))          # profile = TRUE
})

test_that("$paths profile columns are NA when profile = FALSE", {
  p <- report_naive()$paths
  expect_true(all(is.na(p$burden_min)))
  expect_true(all(is.na(p$burden_median)))
  expect_true(all(is.na(p$burden_max)))
  expect_false(anyNA(p$burden_floor))
})

test_that("$readability carries long_stems, long_labels and long_grids", {
  rd <- report_naive()$readability
  expect_true(all(c("stem_threshold", "label_threshold",
                    "long_stems", "long_labels", "long_grids") %in% names(rd)))
  expect_s3_class(rd$long_grids, "tbl_df")
  expect_true("QID19" %in% rd$long_grids$question_id)
})

test_that("routes = adds a $population tibble the same shape as $burden", {
  set.seed(1)
  routes <- data.frame(
    source = "roots",
    n_children = rbinom(60, 3, 0.3), n_cars = rbinom(60, 2, 0.6),
    n_vans = 0, n_campers = 0,
    loop_other_adults = rbinom(60, 3, 0.4),
    loop_children = rbinom(60, 2, 0.4), loop_vehicles = rbinom(60, 2, 0.5)
  )
  r <- burden_report(fx(), routes = routes, certainty = FALSE)
  expect_s3_class(r$population, "tbl_df")
  expect_equal(names(r$population), names(r$burden))
  expect_equal(as.character(r$population$statistic),
               c("min", "p25", "median", "p75", "max"))
  expect_match(paste(r$warnings, collapse = " "), "route", ignore.case = TRUE)
})

test_that("print.burden_report renders the headline and returns invisibly", {
  r <- report_full()
  out <- format(r)
  expect_true(any(grepl("Survey Burden Report", out)))
  expect_true(any(grepl("Neighbourhood Travel Survey (demo)", out, fixed = TRUE)))
  expect_true(any(grepl("Benchmark", out)))
  expect_true(any(grepl("Burden by block", out)))
  expect_true(any(grepl("Highest-burden questions", out)))
  expect_output(res <- withVisible(print(r)))
  expect_identical(res$visible, FALSE)
})

test_that("print shows a Minimum/Maximum-only burden table under profile = FALSE", {
  out <- format(report_naive())
  expect_true(any(grepl("Maximum", out)))
  expect_false(any(grepl("25th percentile", out)))
})

test_that("print caps the warnings list and points to $warnings when it overflows", {
  r <- burden_report(fx(), certainty = FALSE, rare_threshold = 50,
                     stem_warning_threshold = 5L, label_warning_threshold = 1L)
  expect_gt(length(r$warnings), 5)
  out <- format(r)
  expect_true(any(grepl("first 5 shown", out, fixed = TRUE)))
  expect_true(any(grepl("full list in .\\$warnings", out)))
})

test_that("summary(burden_report) returns a short headline object", {
  r <- report_full()
  s <- summary(r)
  expect_s3_class(s, "summary.burden_report")
  out <- capture.output(print(s))
  expect_true(any(grepl("Neighbourhood Travel Survey", out)))
  expect_true(any(grepl("106", out)) && any(grepl("143", out)))
  expect_output(res <- withVisible(print(s)))
  expect_identical(res$visible, FALSE)
})

# a survey whose flow starts with an unconditional EndSurvey: every enumerated
# path terminates early, so there is no completing path to summarise a spread over
no_complete_qsf <- function() {
  q <- read_qsf(demo_qsf())
  fl <- which(vapply(q$SurveyElements,
                     function(e) identical(e$Element, "FL"), logical(1)))
  q$SurveyElements[[fl]]$Payload$Flow <- c(
    list(list(Type = "EndSurvey", FlowID = "F_kill")),
    q$SurveyElements[[fl]]$Payload$Flow
  )
  q
}

test_that("burden_report degrades gracefully when no path completes", {
  q <- no_complete_qsf()

  expect_no_error(r <- burden_report(q, certainty = FALSE, quiet = TRUE))
  expect_s3_class(r, "burden_report")
  expect_equal(r$instrument$n_complete_paths, 0L)
  expect_true(all(is.na(r$burden$points)))
  expect_equal(attr(r$burden, "basis"), "none")
  expect_match(paste(r$warnings, collapse = " "),
               "no completing path", ignore.case = TRUE)
  expect_no_error(format(r))
  expect_no_error(capture.output(print(summary(r))))
})

test_that("the no-completing-path guard also holds under profile = FALSE", {
  expect_no_error(
    burden_report(no_complete_qsf(), profile = FALSE, certainty = FALSE, quiet = TRUE)
  )
})

test_that("burden_report is silent under quiet = TRUE", {
  expect_silent(burden_report(fx(), certainty = FALSE, quiet = TRUE))
})

test_that("burden_report reports progress under quiet = FALSE", {
  withr::local_options(cli.progress_show_after = 0, cli.progress_clear = FALSE)
  expect_message(burden_report(fx(), certainty = FALSE, quiet = FALSE))
})
