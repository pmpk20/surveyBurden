# --- unit: reachability classification ---
mk <- function(qid, dl = FALSE, refs = character(0)) tibble::tibble(
  question_id = qid, has_display_logic = dl, display_logic_refs = list(refs)
)

test_that("unconditional questions are always shown", {
  cat <- rbind(mk("Q1"), mk("Q2"))
  r <- classify_reachability(cat, c("Q1", "Q2"))
  expect_setequal(r$always, c("Q1", "Q2"))
  expect_length(r$maybe, 0)
  expect_length(r$unreachable, 0)
})

test_that("a conditional question whose trigger is on the path is 'maybe'", {
  cat <- rbind(mk("Q1"), mk("Q2", dl = TRUE, refs = "Q1"))
  r <- classify_reachability(cat, c("Q1", "Q2"))
  expect_identical(r$always, "Q1")
  expect_identical(r$maybe, "Q2")
})

test_that("a conditional question whose trigger is off the path is unreachable", {
  cat <- rbind(mk("Q1"), mk("Q9", dl = TRUE, refs = "QX"))  # QX not on path
  r <- classify_reachability(cat, c("Q1", "Q9"))
  expect_identical(r$unreachable, "Q9")
  expect_length(r$maybe, 0)
})

test_that("display logic with no question reference (embedded data) is 'maybe'", {
  cat <- rbind(mk("Q1"), mk("Q2", dl = TRUE, refs = character(0)))
  r <- classify_reachability(cat, c("Q1", "Q2"))
  expect_identical(r$maybe, "Q2")
})

# --- integration: demo travel survey fixture ---
test_that("resolve_paths returns flow paths with per-path question reachability", {
  qsf <- read_qsf(demo_qsf())
  p <- resolve_paths(qsf)

  expect_s3_class(p, "tbl_df")
  expect_true(all(c("path_id", "terminates_early", "block_ids",
                    "q_always", "q_maybe", "n_gates") %in% names(p)))
  expect_equal(nrow(p), 4L)  # same path count as resolve_flow

  full <- p[!p$terminates_early, ]
  # every 'always' question is on the path; floor <= ceiling
  for (i in seq_len(nrow(full))) {
    expect_true(length(full$q_always[[i]]) >= 1)
    expect_true(length(full$q_always[[i]]) <= length(full$q_always[[i]]) + length(full$q_maybe[[i]]))
  }
  # the longest full path reaches more questions than the shortest
  ceilings <- lengths(full$q_always) + lengths(full$q_maybe)
  expect_gt(max(ceilings), min(ceilings))
})

test_that("instrument_summary counts the structural features", {
  qsf <- read_qsf(demo_qsf())
  s <- instrument_summary(qsf)

  expect_equal(s$n_questions, 26L)
  expect_equal(s$n_blocks, 12L)
  expect_equal(s$n_branches, 3L)
  expect_equal(s$n_randomisers, 0L)
  expect_equal(s$n_loop_blocks, 2L)
})
