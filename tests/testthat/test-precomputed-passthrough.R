# The burden pipeline re-parses / re-scores / re-resolves the same .qsf several
# times over. burden_report() now computes each once and threads the result
# through optional args. These tests pin the contract: passing a precomputed
# value must give output identical to letting the function compute its own.

q_fx <- function() read_qsf(demo_qsf())

test_that("resolve_paths output is identical with precomputed catalogue + blocks", {
  q <- q_fx()
  a <- resolve_paths(q)
  b <- resolve_paths(q, catalogue = parse_qsf(q), blocks = resolve_live_blocks(q))
  expect_identical(a, b)
})

test_that("instrument_summary output is identical with a precomputed blocks table", {
  q <- q_fx()
  expect_identical(instrument_summary(q),
                   instrument_summary(q, blocks = resolve_live_blocks(q)))
})

test_that("path_burden output is identical with precomputed paths + scored", {
  q <- q_fx(); w <- gfs_weights()
  a <- path_burden(q, weights = w)
  b <- path_burden(q, weights = w,
                   paths = resolve_paths(q), scored = score_burden(parse_qsf(q), w))
  expect_identical(a, b)
})

test_that("burden_engine output is identical with precomputed paths + scored + blocks", {
  q <- q_fx(); w <- gfs_weights()
  a <- burden_engine(q, weights = w)
  b <- burden_engine(q, weights = w,
                     paths  = resolve_paths(q),
                     scored = score_burden(parse_qsf(q), w),
                     blocks = resolve_live_blocks(q))
  expect_identical(a, b)
})

test_that("burden_engine output is identical with a precomputed parsed_dl map", {
  q <- q_fx(); w <- gfs_weights()
  sc <- score_burden(parse_qsf(q), w)
  a <- burden_engine(q, weights = w)
  b <- burden_engine(q, weights = w, parsed_dl = parse_all_display_logic(q, sc))
  expect_identical(a, b)
})

test_that("calculation_certainty output is identical with a precomputed parsed_dl map", {
  q <- q_fx(); w <- gfs_weights()
  sc <- score_burden(parse_qsf(q), w)
  a <- calculation_certainty(q, weights = w)
  b <- calculation_certainty(q, weights = w, parsed_dl = parse_all_display_logic(q, sc))
  expect_identical(a, b)
})

test_that("path_burden_profile output is identical when handed a prebuilt engine", {
  q <- q_fx(); w <- gfs_weights()
  a <- path_burden_profile(q, weights = w)
  b <- path_burden_profile(q, weights = w, engine = burden_engine(q, weights = w))
  expect_identical(a, b)
})

test_that("calculation_certainty output is identical with precomputed paths + scored + blocks", {
  q <- q_fx(); w <- gfs_weights()
  a <- calculation_certainty(q, weights = w)
  b <- calculation_certainty(q, weights = w,
                             paths  = resolve_paths(q),
                             scored = score_burden(parse_qsf(q), w),
                             blocks = resolve_live_blocks(q))
  expect_identical(a, b)
})

test_that("burden_report output is unchanged by the internal single-pass wiring", {
  # value parity: the whole report, computed the fast way, matches the golden
  # numbers the per-function tests already pin. This is a belt-and-braces check
  # that the threading in burden_report() did not drop or reorder anything.
  q <- q_fx()
  r <- burden_report(q, certainty = TRUE, quiet = TRUE)
  expect_equal(r$burden$points,
               c(106, 117, 123, 129, 143), tolerance = 1e-8)
  expect_equal(nrow(r$paths), 4L)
  expect_equal(r$certainty$paths$n_full, 2L)
})
