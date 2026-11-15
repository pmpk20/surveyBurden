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





# --- integration: demo travel survey fixture ---



