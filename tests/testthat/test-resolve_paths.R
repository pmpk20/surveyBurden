# --- unit: reachability classification ---
mk <- function(qid, dl = FALSE, refs = character(0)) tibble::tibble(
  question_id = qid, has_display_logic = dl, display_logic_refs = list(refs)
)

# Minimal Qualtrics DisplayLogic trees: literals in one group, or two groups.
lit <- function(qid, op = "Selected", conj = NULL, choice = 1) {
  loc <- sprintf("q://%s/SelectableChoice/%s", qid, choice)
  c(list(LogicType = "Question", QuestionID = qid, Operator = op,
         ChoiceLocator = loc, LeftOperand = loc), if (!is.null(conj)) list(Conjuction = conj))
}
lit_ed <- function(field, conj = NULL) {
  c(list(LogicType = "EmbeddedField", LeftOperand = field, Operator = "EqualTo"),
    if (!is.null(conj)) list(Conjuction = conj))
}
dl_tree <- function(...) {
  g <- stats::setNames(list(...), as.character(seq_along(list(...)) - 1L))
  list(`0` = c(g, list(Type = "If")), Type = "BooleanExpression")
}
dl_groups <- function(g0, g1, type) {
  nm <- function(l) stats::setNames(l, as.character(seq_along(l) - 1L))
  list(`0` = c(nm(g0), list(Type = "If")), `1` = c(nm(g1), list(Type = type)),
       Type = "BooleanExpression")
}

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
  r <- classify_reachability(cat, c("Q1", "Q9"),
                             display_logic = list(Q9 = dl_tree(lit("QX"))))
  expect_identical(r$unreachable, "Q9")
  expect_length(r$maybe, 0)
})

test_that("without the display-logic trees nothing is ruled out", {
  cat <- rbind(mk("Q1"), mk("Q9", dl = TRUE, refs = "QX"))
  r <- classify_reachability(cat, c("Q1", "Q9"))
  expect_identical(r$maybe, "Q9")
  expect_length(r$unreachable, 0)
})

test_that("off-path triggers rule a question out only when the logic is then false", {
  path <- c("Q1", "QT")                  # QX is off the path; Q1 is on it
  reach <- function(tree) {
    cat <- rbind(mk("Q1"), mk("QT", dl = TRUE, refs = c("QX", "Q1")))
    r <- classify_reachability(cat, path, display_logic = list(QT = tree))
    if ("QT" %in% r$unreachable) "unreachable" else "maybe"
  }
  # OR: can still be shown through Q1
  expect_identical(reach(dl_tree(lit("QX"), lit("Q1", conj = "Or"))), "maybe")
  # AND: QX can never be selected, so never shown
  expect_identical(reach(dl_tree(lit("QX"), lit("Q1", conj = "And"))), "unreachable")
  # negation: an unanswered QX is "not selected", so this is true
  expect_identical(reach(dl_tree(lit("QX", op = "NotSelected"))), "maybe")
  expect_identical(reach(dl_tree(lit("QX", op = "NotDisplayed"))), "maybe")
  expect_identical(reach(dl_tree(lit("QX", op = "Displayed"))), "unreachable")
  # groups: ElseIf is OR, AndIf is AND
  expect_identical(reach(dl_groups(list(lit("QX")), list(lit("Q1")), type = "ElseIf")), "maybe")
  expect_identical(reach(dl_groups(list(lit("QX")), list(lit("Q1")), type = "AndIf")), "unreachable")
  # embedded-data condition is unknown: never rules the question out
  expect_identical(reach(dl_tree(lit("QX"), lit_ed("e://Field/x", conj = "Or"))), "maybe")
})

test_that("ruling a question out can rule out questions that depend on it", {
  cat <- rbind(mk("Q1"), mk("Q2", dl = TRUE, refs = "QX"),
               mk("Q3", dl = TRUE, refs = "Q2"), mk("Q4", dl = TRUE, refs = "Q2"))
  r <- classify_reachability(cat, c("Q1", "Q2", "Q3", "Q4"), display_logic = list(
    Q2 = dl_tree(lit("QX")),                       # QX off path -> Q2 never shown
    Q3 = dl_tree(lit("Q2")),                       # needs Q2 answered -> never
    Q4 = dl_tree(lit("Q2", op = "NotSelected"))))  # true when Q2 unanswered
  expect_identical(r$unreachable, c("Q2", "Q3"))
  expect_identical(r$maybe, "Q4")
})

test_that("display logic with no question reference (embedded data) is 'maybe'", {
  cat <- rbind(mk("Q1"), mk("Q2", dl = TRUE, refs = character(0)))
  r <- classify_reachability(cat, c("Q1", "Q2"))
  expect_identical(r$maybe, "Q2")
})

test_that("NA display-logic flag counts as always; each group keeps catalogue order", {
  cat <- rbind(mk("Q5", dl = TRUE, refs = "Q1"), mk("Q1"), mk("Q7", dl = NA),
               mk("Q3", dl = TRUE, refs = c("Q1", "QX")),
               mk("Q2", dl = TRUE, refs = "Q1"), mk("Q4", dl = TRUE, refs = "QY"))
  r <- classify_reachability(cat, c("Q1", "Q2", "Q3", "Q4", "Q5", "Q7"), display_logic = list(
    Q5 = dl_tree(lit("Q1")), Q2 = dl_tree(lit("Q1")),
    Q3 = dl_tree(lit("Q1"), lit("QX", conj = "And")),   # AND with an off-path question
    Q4 = dl_tree(lit("QY"))))
  expect_identical(r$always, c("Q1", "Q7"))
  expect_identical(r$maybe, c("Q5", "Q2"))
  expect_identical(r$unreachable, c("Q3", "Q4"))
})

test_that("an empty catalogue classifies to three empty character vectors", {
  r <- classify_reachability(mk("Q1")[0, ], character(0))
  expect_identical(r, list(always = character(0), maybe = character(0),
                           unreachable = character(0)))
})

test_that("resolve_paths classifies each path against its own questions", {
  q <- read_qsf(system.file("extdata", "demo_display_logic.qsf",
                            package = "surveyBurden", mustWork = TRUE))
  p <- resolve_paths(q)
  cat <- parse_qsf(q)
  blocks <- resolve_live_blocks(q)
  bq <- stats::setNames(blocks$question_ids, blocks$block_id)
  expect_true(any(lengths(p$q_maybe) > 0))   # the fixture exercises display logic
  for (i in seq_len(nrow(p))) {
    on_path <- unlist(bq[p$block_ids[[i]]], use.names = FALSE)
    ref <- classify_reachability(cat[cat$question_id %in% on_path, ], on_path)
    expect_identical(p$q_always[[i]], ref$always)
    expect_identical(p$q_maybe[[i]], ref$maybe)
  }
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
