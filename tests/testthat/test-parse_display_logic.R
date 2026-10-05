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

test_that("combine_groups chains several ElseIf terms each with AndIf parts", {
  v <- list(FALSE, TRUE, FALSE, TRUE, TRUE)
  t <- c("If", "ElseIf", "AndIf", "ElseIf", "AndIf")
  expect_true(combine_groups(v, t))                  # F | (T & F) | (T & T)
  expect_identical(combine_groups(list(NA, FALSE), c("If", "AndIf")), FALSE)
  expect_identical(combine_groups(list(NA, TRUE), c("If", "ElseIf")), TRUE)
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

test_that("combine_literals splits at Or and ANDs each run, three-valued", {
  expect_true(combine_literals(list(TRUE, TRUE, FALSE), c(NA, "Or", "And")))
  expect_false(combine_literals(list(FALSE, TRUE, FALSE), c(NA, "Or", "And")))
  expect_identical(combine_literals(list(NA, FALSE, TRUE), c(NA, "And", "Or")), TRUE)
  expect_identical(combine_literals(list(NA, TRUE), c(NA, "And")), NA)
  expect_identical(combine_literals(list(c(TRUE, FALSE), c(FALSE, TRUE), c(FALSE, TRUE)),
                                    c(NA, "Or", "And")), c(TRUE, TRUE))
})
