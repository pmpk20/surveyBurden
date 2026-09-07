# Generates tests/testthat/fixtures/synthetic_edge_cases.qsf
#
# A small synthetic Qualtrics survey exercising structures that do NOT appear in
# the main demo fixture, so the parser / scorer / flow resolver are tested
# beyond one instrument. Run from the package root:  Rscript data-raw/make_synthetic_qsf.R
#
# Structures covered:
#   - a zero-question block                              (BL_empty)
#   - a question with empty QuestionText                 (QID_notext)
#   - a Matrix / MultipleAnswer question                 (QID_matmulti)
#   - a rank-order (RO) question                         (QID_rank)
#   - a constant-sum (CS) question                       (QID_cs)
#   - a Slider / STAR question                           (QID_star)
#   - an unmapped question type (SBS)                     (QID_sbs)
#   - a descriptive (DB) block with > 100 words          (QID_longdb)
#   - display logic referencing an embedded data field   (QID_dl_ed)
#   - display logic using OR across two groups            (QID_dl_or)
#   - a BlockRandomizer flow element
#   - nested branches (branch inside a branch)
#   - an EndSurvey inside a branch (screen-out)

lit_ed <- function(field) list(
  LogicType = "EmbeddedField", LeftOperand = field, Operator = "EqualTo",
  RightOperand = "1", Type = "Expression"
)
lit_q <- function(qid, choice, conj = NULL) {
  loc <- sprintf("q://%s/SelectableChoice/%s", qid, choice)
  x <- list(LogicType = "Question", QuestionID = qid, Operator = "Selected",
            LeftOperand = loc, ChoiceLocator = loc, Type = "Expression")
  if (!is.null(conj)) x$Conjuction <- conj
  x
}
grp <- function(...) { g <- list(...); names(g) <- as.character(seq_along(g) - 1L); g$Type <- "If"; g }
dl  <- function(...) { d <- list(...); names(d) <- as.character(seq_along(d) - 1L)
                       d$Type <- "BooleanExpression"; d$inPage <- FALSE; d }

choices <- function(labels) stats::setNames(
  lapply(labels, function(l) list(Display = l)), as.character(seq_along(labels))
)

sq <- function(qid, type, selector, sub = "", text = "Question text.",
               ch = NULL, ans = NULL, displaylogic = NULL, validation = NULL) {
  payload <- list(
    QuestionID = qid, QuestionType = type, Selector = selector,
    SubSelector = sub, QuestionText = text,
    DataExportTag = qid, QuestionDescription = substr(text, 1, 30)
  )
  if (!is.null(ch))  payload$Choices <- ch
  if (!is.null(ans)) payload$Answers <- ans
  if (!is.null(displaylogic)) payload$DisplayLogic <- displaylogic
  if (!is.null(validation))   payload$Validation <- validation
  list(SurveyID = "SV_synthetic", Element = "SQ", PrimaryAttribute = qid,
       SecondaryAttribute = substr(text, 1, 30), Payload = payload)
}

long_text <- paste(rep("This paragraph exists only to exceed one hundred words so the descriptive-block length branch of the scorer is exercised by the synthetic fixture.", 6), collapse = " ")

questions <- list(
  sq("QID_longdb", "DB", "TB", text = long_text),
  sq("QID_notext", "MC", "SAVR", text = "", ch = choices(c("Yes", "No"))),
  sq("QID_matmulti", "Matrix", "Likert", "MultipleAnswer",
     text = "Select every option that applies in each row.",
     ch = choices(c("Row one", "Row two", "Row three")),
     ans = choices(c("A", "B", "C"))),
  sq("QID_rank", "RO", "DL", text = "Rank these in order of preference.",
     ch = choices(c("Alpha", "Bravo", "Charlie", "Delta"))),
  sq("QID_cs", "CS", "HSLIDER", text = "Allocate 100 points across the options.",
     ch = choices(c("Option A", "Option B", "Option C"))),
  sq("QID_star", "Slider", "STAR", text = "Rate your satisfaction.",
     ch = choices(c("Overall"))),
  sq("QID_sbs", "SBS", "SBSMatrix", text = "Side-by-side question (unmapped type).",
     ch = choices(c("Row one", "Row two"))),
  sq("QID_gate", "MC", "SAVR", text = "Do you own a car?",
     ch = choices(c("Yes", "No"))),
  sq("QID_dl_ed", "MC", "SAVR", text = "Shown only when the embedded flag is set.",
     ch = choices(c("Yes", "No")),
     displaylogic = dl(grp(lit_ed("edFlag")))),
  sq("QID_dl_or", "MC", "SAVR", text = "Shown when gate=Yes OR embedded flag set.",
     ch = choices(c("Yes", "No")),
     displaylogic = dl(grp(lit_q("QID_gate", "1")), grp(lit_ed("edFlag")))),
  sq("QID_branchq", "MC", "SAVR", text = "Only reached through nested branches.",
     ch = choices(c("Yes", "No"))),
  sq("QID_screenq", "MC", "SAVR", text = "Answer before the potential screen-out.",
     ch = choices(c("Continue", "Stop"))),
  sq("QID_final", "MC", "SAVR", text = "Final question.", ch = choices(c("Done")))
)

qref <- function(qid) list(Type = "Question", QuestionID = qid)
block <- function(id, desc, qids, type = "Standard") list(
  Type = type, SubType = "", Description = desc, ID = id,
  BlockElements = lapply(qids, qref)
)

block_payload <- list(
  block("BL_intro",   "INTRO",            "QID_longdb"),
  block("BL_empty",   "EMPTY BLOCK",      character(0)),
  block("BL_types",   "EXOTIC TYPES",
        c("QID_notext", "QID_matmulti", "QID_rank", "QID_cs", "QID_star", "QID_sbs")),
  block("BL_gate",    "GATE",             c("QID_gate", "QID_dl_ed", "QID_dl_or")),
  block("BL_branch",  "NESTED BRANCH TARGET", "QID_branchq"),
  block("BL_screen",  "SCREENOUT AREA",   "QID_screenq"),
  block("BL_final",   "FINAL",            "QID_final")
)
names(block_payload) <- as.character(seq_along(block_payload) - 1L)

std  <- function(id) list(Type = "Standard", ID = id, FlowID = paste0("FL_", id))
flow <- list(
  Type = "Root", FlowID = "FL_1",
  Flow = list(
    list(Type = "EmbeddedData", FlowID = "FL_ed",
         EmbeddedData = list(list(Description = "edFlag", Type = "Custom",
                                  Field = "edFlag", VariableType = "String", Value = "1")))
    ,
    list(Type = "BlockRandomizer", FlowID = "FL_rand", SubSet = 1L,
         EvenPresentation = TRUE,
         Flow = list(std("BL_intro"), std("BL_empty")))
    ,
    std("BL_types")
    ,
    list(Type = "Branch", FlowID = "FL_b_outer", Description = "outer",
         BranchLogic = dl(grp(lit_q("QID_gate", "1"))),
         Flow = list(
           list(Type = "Branch", FlowID = "FL_b_inner", Description = "inner",
                BranchLogic = dl(grp(lit_q("QID_notext", "1"))),
                Flow = list(std("BL_branch")))
         ))
    ,
    std("BL_gate")
    ,
    list(Type = "Branch", FlowID = "FL_b_screen", Description = "screen-out",
         BranchLogic = dl(grp(lit_q("QID_screenq", "2"))),
         Flow = list(list(Type = "EndSurvey", FlowID = "FL_end")))
    ,
    std("BL_screen"),
    std("BL_final")
  ),
  Properties = list(Count = 8L)
)

el <- function(element, primary, payload, secondary = "") list(
  SurveyID = "SV_synthetic", Element = element, PrimaryAttribute = primary,
  SecondaryAttribute = secondary, Payload = payload
)

survey_elements <- c(
  list(el("BL", "Survey Blocks", block_payload)),
  list(el("FL", "Survey Flow", flow)),
  list(el("SQ", "QID_longdb", NULL)),  # placeholder, replaced below
  questions
)
survey_elements[[3]] <- NULL  # drop placeholder

qsf <- list(
  SurveyEntry = list(
    SurveyID = "SV_synthetic", SurveyName = "Synthetic Edge Cases",
    SurveyDescription = "", SurveyLanguage = "EN", SurveyStatus = "Active"
  ),
  SurveyElements = survey_elements
)

out <- "tests/testthat/fixtures/synthetic_edge_cases.qsf"
jsonlite::write_json(qsf, out, auto_unbox = TRUE, pretty = TRUE, null = "null")
message("wrote ", out)
