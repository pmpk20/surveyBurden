# --- synthetic DisplayLogic builders ---
lit_q <- function(qid, choice, op = "Selected", conj = NULL) {
  loc <- sprintf("q://%s/SelectableChoice/%s", qid, choice)
  x <- list(LogicType = "Question", QuestionID = qid, Operator = op,
            LeftOperand = loc, ChoiceLocator = loc, Type = "Expression")
  if (!is.null(conj)) x$Conjuction <- conj
  x
}
lit_embed <- function(field, op = "EqualTo", val = "x", conj = NULL) {
  x <- list(LogicType = "EmbeddedField", LeftOperand = field, Operator = op,
            RightOperand = val, Type = "Expression")
  if (!is.null(conj)) x$Conjuction <- conj
  x
}
grp <- function(..., type = "If") {
  g <- list(...); names(g) <- as.character(seq_along(g) - 1L); g$Type <- type; g
}
dl_of <- function(...) {
  d <- list(...); names(d) <- as.character(seq_along(d) - 1L)
  d$Type <- "BooleanExpression"; d
}


test_that("NotSelected inverts", {
  p <- parse_display_logic(dl_of(grp(lit_q("QID10", "1", op = "NotSelected"))))
  expect_false(p$predicate(list(QID10 = "1")))
  expect_true(p$predicate(list(QID10 = "2")))
})




test_that("If / ElseIf / AndIf: AndIf binds first, G0 OR (G1 AND G2)", {
  p <- parse_display_logic(dl_of(
    grp(lit_q("QID9", "1")),
    grp(lit_q("QID9", "2"), type = "ElseIf"),
    grp(lit_q("QID12", "1"), type = "AndIf")
  ))
  expect_true(p$predicate(list(QID9 = "1", QID12 = "1")))   # T or (F and T)
  expect_true(p$predicate(list(QID9 = "2", QID12 = "1")))   # F or (T and T)
  expect_true(p$predicate(list(QID9 = "1", QID12 = "2")))   # T or (F and F)
  expect_false(p$predicate(list(QID9 = "2", QID12 = "2")))  # F or (T and F)
  expect_false(p$predicate(list(QID9 = "3", QID12 = "1")))  # F or (F and T)
  # reachability uses the same precedence. With QID12 off the path C is
  # false: A | (B & C) can still hold through A, where (A | B) & C could not.
  expect_true(p$possible("QID12"))
  # with QID9 off the path A and B are false: never shown
  expect_false(p$possible("QID9"))
})








test_that("within a group And binds before Or: A Or B And C is A | (B & C)", {
  p <- parse_display_logic(dl_of(grp(
    lit_q("QID1", "1"),
    lit_q("QID2", "1", conj = "Or"),
    lit_q("QID3", "1", conj = "And")
  )))
  st <- function(a, b, c) list(QID1 = if (a) "1" else "2",
                               QID2 = if (b) "1" else "2",
                               QID3 = if (c) "1" else "2")
  expect_true(p$predicate(st(TRUE, TRUE, FALSE)))    # left-to-right gave FALSE
  expect_false(p$predicate(st(FALSE, TRUE, FALSE)))
  expect_true(p$predicate(st(FALSE, TRUE, TRUE)))
  expect_false(p$predicate(st(FALSE, FALSE, TRUE)))
  # reachability: with QID3 off the path C is false, but A can still hold
  expect_true(p$possible("QID3"))
  expect_false(p$possible(c("QID1", "QID3")))
})

