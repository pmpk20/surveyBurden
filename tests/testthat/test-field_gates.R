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



