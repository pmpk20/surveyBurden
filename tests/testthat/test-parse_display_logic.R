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

test_that("a single Selected literal is true only when that choice is in the state", {
  p <- parse_display_logic(dl_of(grp(lit_q("QID10", "2"))))
  expect_identical(p$vars, "QID10")
  expect_true(p$predicate(list(QID10 = "2")))
  expect_false(p$predicate(list(QID10 = "1")))
  expect_false(p$predicate(list(QID10 = character(0))))
})

test_that("NotSelected inverts", {
  p <- parse_display_logic(dl_of(grp(lit_q("QID10", "1", op = "NotSelected"))))
  expect_false(p$predicate(list(QID10 = "1")))
  expect_true(p$predicate(list(QID10 = "2")))
})

test_that("OR within a group is satisfied by any literal", {
  p <- parse_display_logic(dl_of(grp(
    lit_q("QID9", "1"),
    lit_q("QID9", "2", conj = "Or"),
    lit_q("QID9", "3", conj = "Or")
  )))
  expect_identical(p$vars, "QID9")
  expect_true(p$predicate(list(QID9 = "2")))
  expect_false(p$predicate(list(QID9 = "5")))
})

test_that("an AndIf group ANDs with the running result", {
  p <- parse_display_logic(dl_of(
    grp(lit_q("QID9", "1")),
    grp(lit_q("QID12", "1"), type = "AndIf")
  ))
  expect_setequal(p$vars, c("QID9", "QID12"))
  expect_true(p$predicate(list(QID9 = "1", QID12 = "1")))
  expect_false(p$predicate(list(QID9 = "1", QID12 = "2")))
})

test_that("an ElseIf group ORs with the running result", {
  p <- parse_display_logic(dl_of(
    grp(lit_q("QID9", "1")),
    grp(lit_q("QID12", "3"), type = "ElseIf")
  ))
  expect_setequal(p$vars, c("QID9", "QID12"))
  expect_true(p$predicate(list(QID9 = "1", QID12 = "2")))   # first group true
  expect_true(p$predicate(list(QID9 = "2", QID12 = "3")))   # second group true
  expect_false(p$predicate(list(QID9 = "2", QID12 = "2")))  # neither
})

test_that("If / ElseIf / AndIf fold left-associatively: (G0 OR G1) AND G2", {
  # matches a (statusA OR statusB) AND (not fully-remote) commute gate
  p <- parse_display_logic(dl_of(
    grp(lit_q("QID9", "1")),
    grp(lit_q("QID9", "2"), type = "ElseIf"),
    grp(lit_q("QID12", "1"), type = "AndIf")
  ))
  expect_true(p$predicate(list(QID9 = "1", QID12 = "1")))   # (T or F) and T
  expect_true(p$predicate(list(QID9 = "2", QID12 = "1")))   # (F or T) and T
  expect_false(p$predicate(list(QID9 = "1", QID12 = "2")))  # (T or F) and F
  expect_false(p$predicate(list(QID9 = "3", QID12 = "1")))  # (F or F) and T
})

test_that("missing group Type falls back to AND (pre-2026-09 behaviour)", {
  dl <- dl_of(grp(lit_q("QID9", "1")), grp(lit_q("QID12", "1")))
  dl[["1"]]$Type <- NULL
  p <- parse_display_logic(dl)
  expect_true(p$predicate(list(QID9 = "1", QID12 = "1")))
  expect_false(p$predicate(list(QID9 = "1", QID12 = "2")))
})

test_that("embedded-field literals become a free binary gate", {
  p <- parse_display_logic(dl_of(grp(lit_embed("source", val = "household"))))
  expect_identical(p$vars, "@source")
  expect_true(p$predicate(list(`@source` = TRUE)))
  expect_false(p$predicate(list(`@source` = FALSE)))
})

test_that("Displayed operator resolves against the shown map", {
  p <- parse_display_logic(dl_of(grp(lit_q("QID30", "1", op = "Displayed"))))
  expect_true(p$predicate(list(), shown = c(QID30 = TRUE)))
  expect_false(p$predicate(list(), shown = c(QID30 = FALSE)))
})

test_that("Displayed against a question missing from the shown map is FALSE, not an error", {
  p <- parse_display_logic(dl_of(grp(lit_q("QID30", "1", op = "Displayed"))))
  expect_false(p$predicate(list(), shown = c(QID99 = TRUE)))   # QID30 absent
  expect_false(p$predicate(list(), shown = logical(0)))
  pn <- parse_display_logic(dl_of(grp(lit_q("QID30", "1", op = "NotDisplayed"))))
  expect_true(pn$predicate(list(), shown = c(QID99 = TRUE)))
})

test_that("matrix choice locators keep their statement/scale tail", {
  p <- parse_display_logic(dl_of(grp(lit_q("QID121", "1/16", op = "NotSelected"))))
  expect_true(p$predicate(list(QID121 = character(0))))
  expect_false(p$predicate(list(QID121 = "1/16")))
})
