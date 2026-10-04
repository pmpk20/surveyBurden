# Generates exposure_fixture.qsf, the synthetic survey used by
# test-realised_exposure.R. Run from the package root:
#   Rscript tests/testthat/fixtures/make_exposure_fixture.R
# Every value is invented. The survey covers the hard cases for
# realised_exposure(): a screen-out branch, an embedded-data branch gate, a
# branch on a field set by question JavaScript (absent from the export), a
# Loop & Merge block driven by a numeric response with an in-loop trigger and a
# first-iteration-only question, Displayed() and NotSelected literals, an
# unsupported (quota) literal, page breaks, and a block whose only question is
# always hidden.

mc <- function(qid, text, choices, selector = "SAVR", recode = NULL, dl = NULL,
               js = NULL) {
  p <- list(
    QuestionID = qid, QuestionType = "MC", Selector = selector,
    SubSelector = if (selector == "MAVR") "" else "TX",
    QuestionText = text, DataExportTag = qid,
    QuestionDescription = substr(text, 1, 40),
    Choices = stats::setNames(lapply(choices, function(x) list(Display = x)),
                              as.character(seq_along(choices)))
  )
  if (!is.null(recode)) p$RecodeValues <- as.list(stats::setNames(recode, seq_along(choices)))
  if (!is.null(dl)) p$DisplayLogic <- dl
  if (!is.null(js)) p$QuestionJS <- js
  p
}
te <- function(qid, text, dl = NULL) {
  p <- list(QuestionID = qid, QuestionType = "TE", Selector = "SL", SubSelector = "",
            QuestionText = text, DataExportTag = qid,
            QuestionDescription = substr(text, 1, 40))
  if (!is.null(dl)) p$DisplayLogic <- dl
  p
}
lit_sel <- function(qid, choice, op = "Selected", conj = NULL) {
  l <- list(LogicType = "Question", QuestionID = qid, Operator = op,
            LeftOperand = sprintf("q://%s/SelectableChoice/%s", qid, choice),
            ChoiceLocator = sprintf("q://%s/SelectableChoice/%s", qid, choice),
            Type = "Expression")
  if (!is.null(conj)) l$Conjuction <- conj
  l
}
lit_disp <- function(qid, conj = NULL) {
  l <- list(LogicType = "Question", QuestionID = qid, Operator = "Displayed",
            LeftOperand = sprintf("q://%s/QuestionDisplayed", qid), Type = "Expression")
  if (!is.null(conj)) l$Conjuction <- conj
  l
}
lit_emb <- function(field, op, value) {
  list(LogicType = "EmbeddedField", LeftOperand = field, Operator = op,
       RightOperand = value, Type = "Expression")
}
logic <- function(...) {
  lits <- list(...)
  g <- stats::setNames(lits, as.character(seq_along(lits) - 1L))
  g$Type <- "If"
  list(`0` = g, Type = "BooleanExpression", inPage = FALSE)
}
q_el <- function(qid) list(Type = "Question", QuestionID = qid)
pb <- function() list(Type = "Page Break")
blk <- function(id, desc, els, loop = NULL) {
  b <- list(Type = "Standard", SubType = "", Description = desc, ID = id,
            BlockElements = els)
  if (!is.null(loop)) b$Options <- loop
  b
}

questions <- list(
  mc("QID1", "Do you agree to take part?", c("Yes", "No")),
  mc("QID2", "How many other adults live with you?", c("None", "One", "Two", "Three"),
     selector = "DL", recode = c("0", "1", "2", "3")),
  mc("QID3", "Which of these does your household have?", c("A car", "A bicycle", "Neither"),
     selector = "MAVR",
     js = "Qualtrics.SurveyEngine.addOnPageSubmit(function(){ Qualtrics.SurveyEngine.setEmbeddedData('CarFlag', 1); });"),
  mc("QID4", "Do you drive the car yourself?", c("Yes", "No"),
     dl = logic(lit_sel("QID3", "1"))),
  mc("QID5", "How is this adult related to you?", c("Partner", "Child", "Other")),
  mc("QID6", "How old is this adult?", c("16-29", "30-59", "60+"),
     dl = logic(lit_sel("QID5", "2", op = "NotSelected"))),
  mc("QID7", "Is everyone in the household listed?", c("Yes", "No"),
     dl = logic(list(LogicType = "LoopAndMerge", LeftOperand = "BL3,1",
                     Operator = "EqualTo", RightOperand = "lm://CurrentLoop",
                     Type = "Expression"))),
  te("QID8", "How did you hear about this web survey?"),
  mc("QID9", "How many miles do you drive each week?", c("Under 50", "50-150", "Over 150"),
     dl = logic(lit_disp("QID4"), lit_sel("QID4", "1", conj = "And"))),
  mc("QID10", "Would you take part in a follow-up driving study?", c("Yes", "No"),
     dl = logic(list(LogicType = "Quota", QuotaID = "QO_1", Operator = "QuotaMet",
                     LeftOperand = "qo://QO_1/QuotaMet", Type = "Expression"))),
  mc("QID11", "Why did you decline?", c("No time", "Not interested"),
     dl = logic(lit_sel("QID1", "2"))),
  mc("QID12", "Where do you park the car?", c("Driveway", "Street", "Garage")),
  mc("QID13", "How easy was this survey?", c("Easy", "Neither", "Hard"))
)

blocks <- list(
  blk("BL1", "Intro", list(q_el("QID1"))),
  blk("BL2", "Household", list(q_el("QID2"), pb(), q_el("QID3"), pb(), q_el("QID4"))),
  blk("BL3", "Other adults", list(q_el("QID5"), q_el("QID6"), q_el("QID7")),
      loop = list(Looping = "Question", LoopingOptions = list(
        Locator = "q://QID2/LoopAndMerge/MergeOnNumericResponse?v=3", QID = "QID2",
        ChoiceGroupLocator = "q://QID2/LoopAndMerge/MergeOnNumericResponse",
        Static = list(`1` = list(), `2` = list(), `3` = list()),
        Randomization = "None"))),
  blk("BL4", "Web extras", list(q_el("QID8"))),
  blk("BL5", "Driving", list(q_el("QID9"), q_el("QID10"))),
  blk("BL6", "Decline reasons", list(q_el("QID11"))),
  blk("BL7", "Parking", list(q_el("QID12"))),
  blk("BL8", "Closing", list(q_el("QID13"))),
  blk("BL9", "Unused", list())
)

flow <- list(
  list(Type = "EmbeddedData", FlowID = "FL_ed",
       EmbeddedData = list(
         list(Description = "Mode", Type = "Recipient", Field = "Mode", VariableType = "String"),
         list(Description = "Wave", Type = "Custom", Field = "Wave", VariableType = "String", Value = "2"))),
  list(Type = "Standard", ID = "BL1", FlowID = "FL_1"),
  list(Type = "Branch", FlowID = "FL_b_decline", Description = "declined",
       BranchLogic = logic(lit_sel("QID1", "2")),
       Flow = list(list(Type = "EndSurvey", FlowID = "FL_end_decline"))),
  list(Type = "Standard", ID = "BL2", FlowID = "FL_2"),
  list(Type = "Standard", ID = "BL3", FlowID = "FL_3"),
  list(Type = "Branch", FlowID = "FL_b_web", Description = "web mode",
       BranchLogic = logic(lit_emb("Mode", "EqualTo", "web")),
       Flow = list(list(Type = "Standard", ID = "BL4", FlowID = "FL_4"))),
  list(Type = "Branch", FlowID = "FL_b_wave", Description = "wave 2",
       BranchLogic = logic(lit_emb("Wave", "EqualTo", "2")),
       Flow = list(list(Type = "Standard", ID = "BL5", FlowID = "FL_5"))),
  list(Type = "Standard", ID = "BL6", FlowID = "FL_6"),
  list(Type = "Branch", FlowID = "FL_b_car", Description = "car flag set by JavaScript",
       BranchLogic = logic(lit_emb("CarFlag", "GreaterThan", "0")),
       Flow = list(list(Type = "Standard", ID = "BL7", FlowID = "FL_7"))),
  list(Type = "Standard", ID = "BL8", FlowID = "FL_8")
)

sq <- lapply(questions, function(p) list(
  SurveyID = "SV_exposure", Element = "SQ", PrimaryAttribute = p$QuestionID,
  SecondaryAttribute = p$QuestionDescription, Payload = p))

qsf <- list(
  SurveyEntry = list(SurveyID = "SV_exposure", SurveyName = "Exposure fixture",
                     SurveyLanguage = "EN", SurveyStatus = "Inactive"),
  SurveyElements = c(
    list(list(SurveyID = "SV_exposure", Element = "BL", PrimaryAttribute = "Survey Blocks",
              SecondaryAttribute = "",
              Payload = stats::setNames(blocks, as.character(seq_along(blocks) - 1L)))),
    list(list(SurveyID = "SV_exposure", Element = "FL", PrimaryAttribute = "Survey Flow",
              SecondaryAttribute = "",
              Payload = list(Type = "Root", FlowID = "FL_root", Flow = flow))),
    sq
  )
)

jsonlite::write_json(qsf, "tests/testthat/fixtures/exposure_fixture.qsf",
                     auto_unbox = TRUE, pretty = TRUE, null = "null")
