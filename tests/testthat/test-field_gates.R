# Stored-field (embedded data) display-logic gates. Comparisons on one field
# are evaluated per distinguishable value class (each referenced value, the
# regions between thresholds, an unmatched value, an empty field), so items
# gated on different values of the same field are mutually exclusive.
# Comparisons that cannot be evaluated keep a free true/false gate, reported
# by calculation_certainty().

# One block: QID1 (2 options, 1 point, always shown), QID2 (3 options, 2 points)
# and QID3 (7 options, 3 points) gated by the given logic; field `grp` set in
# the flow.
fg_qsf <- function(dl_a, dl_b) {
  qs <- list(fg_mc("QID1", 2), fg_mc("QID2", 3, dl_a), fg_mc("QID3", 7, dl_b))
  blocks <- list(list(Type = "Standard", SubType = "", Description = "Main", ID = "BL1",
                      BlockElements = lapply(c("QID1", "QID2", "QID3"), function(q)
                        list(Type = "Question", QuestionID = q))))
  flow <- list(
    list(Type = "EmbeddedData", FlowID = "FL_ed",
         EmbeddedData = list(list(Description = "grp", Type = "Recipient", Field = "grp",
                                  VariableType = "String"))),
    list(Type = "Standard", ID = "BL1", FlowID = "FL_1"))
  el <- c(
    list(list(Element = "BL", PrimaryAttribute = "Survey Blocks", SecondaryAttribute = "",
              Payload = stats::setNames(blocks, "0")),
         list(Element = "FL", PrimaryAttribute = "Survey Flow", SecondaryAttribute = "",
              Payload = list(Type = "Root", FlowID = "FL_root", Flow = flow))),
    lapply(qs, function(p) list(Element = "SQ", PrimaryAttribute = p$QuestionID,
                                SecondaryAttribute = "", Payload = p)))
  as_qsf_raw(list(SurveyEntry = list(SurveyID = "SV_fg", SurveyName = "Field gates"),
                  SurveyElements = el))
}
fg_profile <- function(q) {
  pr <- suppressMessages(path_burden_profile(q))
  stopifnot(nrow(pr) == 1L)
  pr$profile[[1]]
}

test_that("items gated on different values of one field are exclusive", {
  q <- fg_qsf(fg_logic(fg_emb("grp", "EqualTo", "1")),
              fg_logic(fg_emb("grp", "EqualTo", "2")))
  pr <- fg_profile(q)
  # base 1; A adds 2, B adds 3: A only = 3, B only = 4, neither = 1
  expect_setequal(pr$burden, c(1, 3, 4))
  expect_false(6 %in% pr$burden)          # never A and B together
  expect_equal(sum(pr$weight), 1)
})

test_that("inequalities on one field are exclusive too", {
  q <- fg_qsf(fg_logic(fg_emb("grp", "GreaterThan", "3")),
              fg_logic(fg_emb("grp", "LessThanOrEqual", "3")))
  pr <- fg_profile(q)
  expect_true(all(c(3, 4) %in% pr$burden))
  expect_false(6 %in% pr$burden)
})

test_that("a field compared to one value gives two classes", {
  p <- parse_display_logic(fg_logic(fg_emb("grp", "EqualTo", "1")))
  st <- gate_states("@grp", "QIDA", list(QIDA = p), c())
  expect_length(st, 2L)
  expect_true(p$predicate(list(`@grp` = "1")))
  expect_false(p$predicate(list(`@grp` = "2")))
  expect_false(p$predicate(list(`@grp` = NA_character_)))
})

test_that("an operator that cannot be evaluated keeps a binary gate and is reported", {
  dl_a <- fg_logic(fg_emb("grp", "Contains", "x"))
  p <- parse_display_logic(dl_a)
  expect_length(p$vars, 1L)
  expect_true(p$predicate(stats::setNames(list(TRUE), p$vars)))
  expect_false(p$predicate(stats::setNames(list(FALSE), p$vars)))

  q <- fg_qsf(dl_a, fg_logic(fg_emb("grp", "EqualTo", "2")))
  ct <- suppressMessages(calculation_certainty(q))
  expect_equal(ct$display_logic$n_binary_field_gates, 1L)
  expect_match(paste(format(ct), collapse = "\n"), "true/false")
})

test_that("evaluable field gates are not counted as binary", {
  q <- fg_qsf(fg_logic(fg_emb("grp", "EqualTo", "1")),
              fg_logic(fg_emb("grp", "EqualTo", "2")))
  ct <- suppressMessages(calculation_certainty(q))
  expect_equal(ct$display_logic$n_binary_field_gates, 0L)
})
