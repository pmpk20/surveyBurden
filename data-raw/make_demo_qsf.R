# Generates inst/extdata/demo_travel_survey.qsf
#
# A FICTIONAL "Neighbourhood Travel Survey" -- invented for this package, not
# taken from any real study. It is the primary test fixture: large enough to
# exercise the whole pipeline (branches, screen-outs, Loop & Merge, matrices,
# dropdowns, multi-select, open text, descriptive blocks, and display logic
# including If / ElseIf / AndIf groups and embedded-field gates).
#
# Run from the package root:  Rscript data-raw/make_demo_qsf.R
#
# Structure:
#   B1  Welcome            DB intro (long)
#   B2  Consent            single choice; decline -> EndSurvey
#   B3  Area check         postcode-area single choice; embedded "InArea" gate
#   B4  About you          age dropdown, gender, work status, disability matrix
#   B5  Household          adults dropdown (drives adult loop), children count
#   B6  Adult loop  [Loop&Merge, v=5]  relationship, age, works
#   B7  Vehicles           own-a-vehicle multi-select (drives vehicle loop),
#                          number of cars dropdown
#   B8  Vehicle loop [Loop&Merge, v=3]  type, fuel (shown unless type = other),
#                          approx value (open numeric)
#   B9  Travel             mode-frequency matrix, journey-purpose matrix
#   B10 Attitudes          7-point agreement matrix
#   B11 Commuting          (shown for employed OR self-employed, AND not fully
#                           remote -- an If/ElseIf/AndIf group) commute mode,
#                           days in office
#   B12 Closing            open-ended comment, recontact consent
#
#   Branches: consent declined -> End; not in area -> End; employed -> B11.

lit_q <- function(qid, choice, op = "Selected", conj = NULL) {
  loc <- sprintf("q://%s/SelectableChoice/%s", qid, choice)
  x <- list(LogicType = "Question", QuestionID = qid, Operator = op,
            LeftOperand = loc, ChoiceLocator = loc, Type = "Expression")
  if (!is.null(conj)) x$Conjuction <- conj
  x
}
lit_disp <- function(qid, op = "Displayed", conj = NULL) {
  x <- list(LogicType = "Question", QuestionID = qid, Operator = op,
            LeftOperand = sprintf("q://%s/ChoiceDisplayed/1", qid), Type = "Expression")
  if (!is.null(conj)) x$Conjuction <- conj
  x
}
lit_ed <- function(field, op = "EqualTo", right = "1", conj = NULL) {
  x <- list(LogicType = "EmbeddedField", LeftOperand = field, Operator = op,
            RightOperand = right, Type = "Expression")
  if (!is.null(conj)) x$Conjuction <- conj
  x
}
grp <- function(..., type = "If") {
  g <- list(...); names(g) <- as.character(seq_along(g) - 1L); g$Type <- type; g
}
dl <- function(...) {
  d <- list(...); names(d) <- as.character(seq_along(d) - 1L)
  d$Type <- "BooleanExpression"; d$inPage <- FALSE; d
}
choices <- function(labels, recode = NULL) {
  ch <- stats::setNames(lapply(labels, function(l) list(Display = l)),
                        as.character(seq_along(labels)))
  ch
}
recodes <- function(...) {
  v <- c(...); stats::setNames(as.list(as.character(v)), as.character(seq_along(v)))
}

sq <- function(qid, type, selector, sub = "", text = "Question text.",
               ch = NULL, ans = NULL, dl = NULL, valid = NULL, recode = NULL) {
  p <- list(QuestionID = qid, QuestionType = type, Selector = selector,
            SubSelector = sub, QuestionText = text, DataExportTag = qid,
            QuestionDescription = substr(text, 1, 40))
  if (!is.null(ch))     p$Choices <- ch
  if (!is.null(ans))    p$Answers <- ans
  if (!is.null(dl))     p$DisplayLogic <- dl
  if (!is.null(valid))  p$Validation <- valid
  if (!is.null(recode)) p$RecodeValues <- recode
  list(SurveyID = "SV_demo", Element = "SQ", PrimaryAttribute = qid,
       SecondaryAttribute = substr(text, 1, 40), Payload = p)
}

welcome_text <- paste(
  "Welcome, and thank you for taking part in the Neighbourhood Travel Survey.",
  "This is a fictional questionnaire used only to test the surveyBurden R",
  "package; it is not a real study and collects nothing. The questions below",
  "mirror the shapes a real travel survey uses -- a few single-choice items, a",
  "couple of grids, an open comment box, and two sections that repeat once for",
  "each adult in your household and once for each vehicle you own. There are no",
  "right answers. If a question does not apply to you, choose the option that",
  "fits best and move on. The survey takes most people around twenty minutes.",
  "Your progress is saved automatically as you go, and you can stop and come",
  "back later using the same link on the same device. When you are ready,",
  "select Next to begin.")

forced <- list(Settings = list(ForceResponse = "ON", ForceResponseType = "ON",
                               Type = "None"))

Q <- list(
  # B1
  sq("QID1", "DB", "TB", text = welcome_text),
  # B2
  sq("QID2", "MC", "SAVR", text = "Do you agree to take part in this fictional survey?",
     ch = choices(c("Yes, I agree", "No, I do not agree")), valid = forced),
  # B3
  sq("QID3", "MC", "SAVR",
     text = paste("Which of these best describes where you live right now? We can",
                  "only include people whose home falls inside the boundary of the",
                  "fictional study area, so please pick the option that fits your",
                  "situation best."),
     ch = choices(c("Inside the study area", "Just outside it", "Somewhere else entirely")),
     valid = forced),
  # B4
  sq("QID4", "MC", "DL", text = "How old are you?",
     ch = choices(as.character(16:90))),
  sq("QID5", "MC", "SAVR", text = "How do you describe your gender?",
     ch = choices(c("Woman", "Man", "In another way", "Prefer not to say"))),
  sq("QID6", "MC", "SAVR", text = "Which best describes your current situation?",
     ch = choices(c("Employed", "Self-employed", "Student", "Retired",
                    "Looking after home or family", "Not working for another reason")),
     recode = recodes(1, 2, 3, 4, 5, 6)),
  sq("QID7", "Matrix", "Likert", "SingleAnswer",
     text = "For each area, do you have a condition that makes travel harder?",
     ch = choices(c("Getting around on foot", "Using buses or trains",
                    "Driving", "Cycling")),
     ans = choices(c("Yes, a lot", "Yes, a little", "No"))),
  sq("QID8", "TE", "SL", text = "In a few words, anything else about your travel needs?"),
  # B5
  sq("QID9", "MC", "DL",
     text = "Including yourself, how many adults aged 16 or over live in your household?",
     ch = choices(as.character(1:8)), recode = recodes(1:8)),
  sq("QID10", "MC", "SAVR", text = "How many children under 16 live with you?",
     ch = choices(c("None", "One", "Two", "Three or more"))),
  # B6 (adult loop)
  sq("QID11", "MC", "SAVR", text = "What is this person's relationship to you?",
     ch = choices(c("Partner or spouse", "Child", "Parent", "Other relative",
                    "Flatmate or lodger", "Other"))),
  sq("QID12", "MC", "DL", text = "Roughly how old is this person?",
     ch = choices(as.character(16:90))),
  sq("QID13", "MC", "SAVR", text = "Does this person do any paid work?",
     ch = choices(c("Yes", "No")),
     dl = dl(grp(lit_q("QID11", "6", op = "NotSelected")))),
  # B7
  sq("QID14", "MC", "MAVR",
     text = "Which of these does your household own or have use of? Select all that apply.",
     ch = choices(c("A car", "A van", "A motorbike or moped", "A bicycle",
                    "An e-bike", "None of these"))),
  sq("QID15", "MC", "DL", text = "How many cars does your household have?",
     ch = choices(as.character(0:6)), recode = recodes(0:6),
     dl = dl(grp(lit_q("QID14", "1")))),
  # B8 (vehicle loop)
  sq("QID16", "MC", "SAVR", text = "What type of vehicle is this?",
     ch = choices(c("Small car", "Medium car", "Large car or SUV", "Van",
                    "Motorbike or moped", "Other")),
     recode = recodes(3, 1, 2, 4, 5, 9)),
  sq("QID17", "MC", "SAVR", text = "What does it run on?",
     ch = choices(c("Petrol", "Diesel", "Hybrid", "Fully electric", "Something else")),
     dl = dl(grp(lit_q("QID16", "9", op = "NotSelected")))),
  sq("QID18", "TE", "SL", valid = list(Settings = list(ContentType = "ValidNumber")),
     text = "Roughly what is it worth today, in pounds? A rough guess is fine."),
  # B9
  sq("QID19", "Matrix", "Likert", "SingleAnswer",
     text = "In the past month, how often did you use each of these?",
     ch = choices(c("Walking", "Cycling", "Bus", "Train or tram", "Car as driver",
                    "Car as passenger", "Taxi or private hire")),
     ans = choices(c("Most days", "About once a week", "Once or twice", "Not at all"))),
  sq("QID20", "Matrix", "Likert", "SingleAnswer",
     text = "And for each of these reasons for travelling, how often in the past month?",
     ch = choices(c("Getting to work or study", "Shopping", "Seeing friends or family",
                    "Leisure or days out", "Taking someone else somewhere",
                    "Medical appointments")),
     ans = choices(c("Most days", "Weekly", "Now and then", "Never"))),
  # B10
  sq("QID21", "Matrix", "Likert", "SingleAnswer",
     text = "How much do you agree with each statement?",
     ch = choices(c("I would like to drive less than I do",
                    "Public transport near me is good enough to rely on",
                    "Cycling on local roads feels safe to me",
                    "The cost of running a car worries me",
                    "I enjoy walking for everyday trips",
                    "New technology will make travel easier for me")),
     ans = choices(c("Strongly disagree", "Disagree", "Slightly disagree",
                     "Neither", "Slightly agree", "Agree", "Strongly agree"))),
  # B11 (commuting -- If/ElseIf/AndIf: (employed OR self-employed) AND not fully remote)
  sq("QID22", "MC", "SAVR", text = "How do you usually get to work?",
     ch = choices(c("Walk", "Cycle", "Bus", "Train", "Drive", "Get a lift",
                    "It varies", "I work from home")),
     dl = dl(grp(lit_q("QID6", "1")),
             grp(lit_q("QID6", "2"), type = "ElseIf"),
             grp(lit_q("QID23", "1", op = "NotSelected"), type = "AndIf"))),
  sq("QID23", "MC", "SAVR", text = "Do you work fully from home?",
     ch = choices(c("Yes, fully from home", "No, at least sometimes in a workplace")),
     dl = dl(grp(lit_q("QID6", "1")),
             grp(lit_q("QID6", "2"), type = "ElseIf"))),
  sq("QID24", "MC", "SAVR", text = "In a normal week, how many days do you travel to a workplace?",
     ch = choices(c("Fewer than one", "One or two", "Three or four", "Five or more")),
     dl = dl(grp(lit_disp("QID22"), lit_q("QID23", "2", conj = "And"))),
     valid = forced),
  # B12
  sq("QID25", "TE", "ML",
     text = "Is there anything else about how you get around that you would like to tell us?"),
  sq("QID26", "MC", "SAVR",
     text = "Would you be happy for a researcher to contact you about a follow-up?",
     ch = choices(c("Yes", "No")))
)

qref <- function(qid) list(Type = "Question", QuestionID = qid)
block <- function(id, desc, qids, loop_qid = NULL, loop_max = NULL) {
  b <- list(Type = "Standard", SubType = "", Description = desc, ID = id,
            BlockElements = lapply(qids, qref))
  if (!is.null(loop_qid)) {
    b$Options <- list(
      Looping = "Question",
      LoopingOptions = list(
        Locator = sprintf("q://%s/LoopAndMerge/MergeOnNumericResponse?v=%d", loop_qid, loop_max),
        QID = loop_qid,
        ChoiceGroupLocator = sprintf("q://%s/LoopAndMerge/MergeOnNumericResponse", loop_qid),
        Static = stats::setNames(rep(list(list()), loop_max), as.character(seq_len(loop_max))),
        Randomization = "None"))
  }
  b
}

blocks <- list(
  block("BL1",  "Welcome",              "QID1"),
  block("BL2",  "Consent",              "QID2"),
  block("BL3",  "Area check",           "QID3"),
  block("BL4",  "About you",            c("QID4", "QID5", "QID6", "QID7", "QID8")),
  block("BL5",  "Household",             c("QID9", "QID10")),
  block("BL6",  "Other adults",          c("QID11", "QID12", "QID13"),
        loop_qid = "QID9", loop_max = 5),
  block("BL7",  "Vehicles",              c("QID14", "QID15")),
  block("BL8",  "Vehicle details",       c("QID16", "QID17", "QID18"),
        loop_qid = "QID15", loop_max = 3),
  block("BL9",  "Travel",                c("QID19", "QID20")),
  block("BL10", "Attitudes",             "QID21"),
  block("BL11", "Commuting",             c("QID22", "QID23", "QID24")),
  block("BL12", "Closing",               c("QID25", "QID26")),
  block("BLtrash", "Bin/Unused",         character(0))
)
names(blocks) <- as.character(seq_along(blocks) - 1L)

std   <- function(id) list(Type = "Standard", ID = id, FlowID = paste0("FL_", id))
endsv <- function(id) list(Type = "EndSurvey", FlowID = id)

flow <- list(
  Type = "Root", FlowID = "FL_root",
  Flow = list(
    list(Type = "EmbeddedData", FlowID = "FL_ed",
         EmbeddedData = list(
           list(Description = "InArea", Type = "Custom", Field = "InArea",
                VariableType = "String", Value = "1"))),
    std("BL1"), std("BL2"),
    list(Type = "Branch", FlowID = "FL_b_consent", Description = "consent declined",
         BranchLogic = dl(grp(lit_q("QID2", "2"))),
         Flow = list(endsv("FL_end_consent"))),
    std("BL3"),
    list(Type = "Branch", FlowID = "FL_b_area", Description = "not in study area",
         BranchLogic = dl(grp(lit_q("QID3", "1", op = "NotSelected"))),
         Flow = list(endsv("FL_end_area"))),
    std("BL4"), std("BL5"), std("BL6"), std("BL7"), std("BL8"),
    std("BL9"), std("BL10"),
    list(Type = "Branch", FlowID = "FL_b_work", Description = "employed -> commuting",
         BranchLogic = dl(grp(lit_q("QID6", "1")),
                          grp(lit_q("QID6", "2"), type = "ElseIf")),
         Flow = list(std("BL11"))),
    std("BL12")
  ),
  Properties = list(Count = 20L)
)

el <- function(element, primary, payload) list(
  SurveyID = "SV_demo", Element = element, PrimaryAttribute = primary,
  SecondaryAttribute = "", Payload = payload)

qsf <- list(
  SurveyEntry = list(
    SurveyID = "SV_demo000000000000", SurveyName = "Neighbourhood Travel Survey (demo)",
    SurveyDescription = NULL, SurveyLanguage = "EN", SurveyStatus = "Inactive",
    SurveyCreationDate = "2026-01-01 00:00:00"),
  SurveyElements = c(list(el("BL", "Survey Blocks", blocks),
                          el("FL", "Survey Flow", flow)),
                     Q)
)

out <- "inst/extdata/demo_travel_survey.qsf"
jsonlite::write_json(qsf, out, auto_unbox = TRUE, pretty = TRUE, null = "null")
message("wrote ", out, " -- ", length(Q), " questions, ", length(blocks), " blocks")
