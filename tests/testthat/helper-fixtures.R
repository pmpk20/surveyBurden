# Absolute path to the bundled demo survey. Under pkgload::load_all() and
# under R CMD check this resolves to inst/extdata/.
demo_qsf <- function() {
  system.file("extdata", "demo_travel_survey.qsf",
              package = "surveyBurden", mustWork = TRUE)
}

# Small QSF building blocks (shared by field-gate and loop tests)
fg_mc <- function(qid, n, dl = NULL) {
  p <- list(QuestionID = qid, QuestionType = "MC", Selector = "SAVR", SubSelector = "TX",
            QuestionText = paste("Question", qid), DataExportTag = qid,
            QuestionDescription = qid,
            Choices = stats::setNames(lapply(seq_len(n), function(i) list(Display = paste("c", i))),
                                      as.character(seq_len(n))))
  if (!is.null(dl)) p$DisplayLogic <- dl
  p
}
fg_emb <- function(field, op, value, conj = NULL) {
  l <- list(LogicType = "EmbeddedField", LeftOperand = field, Operator = op,
            RightOperand = value, Type = "Expression")
  if (!is.null(conj)) l$Conjuction <- conj
  l
}
fg_logic <- function(...) {
  lits <- list(...)
  g <- stats::setNames(lits, as.character(seq_along(lits) - 1L))
  g$Type <- "If"
  list(`0` = g, Type = "BooleanExpression", inPage = FALSE)
}

# Loop & Merge fixtures (shared by loop-display and traversal tests)
lp_pos_logic <- function(block = "BL_x", k = 1, op = "EqualTo") {
  list(`0` = list(`0` = list(LogicType = "LoopAndMerge",
                             LeftOperand = paste0(block, ",", k), Operator = op,
                             RightOperand = "lm://CurrentLoop", Type = "Expression"),
                  Type = "If"),
       Type = "BooleanExpression", inPage = FALSE)
}

# Question-literal logic: `qid` has choice `choice` selected.
lp_sel <- function(qid, choice, conj = NULL) {
  loc <- sprintf("q://%s/SelectableChoice/%s", qid, choice)
  x <- list(LogicType = "Question", QuestionID = qid, Operator = "Selected",
            LeftOperand = loc, ChoiceLocator = loc, Type = "Expression")
  if (!is.null(conj)) x$Conjuction <- conj
  x
}
lp_forced <- function(p, fr = "ON") { p$Validation <- list(Settings = list(ForceResponse = fr)); p }

# Blocks in flow order. `blocks` is a list of list(id, qs = list of payloads,
# loop = NULL or a static iteration count).
lp_qsf <- function(blocks) {
  bl <- lapply(blocks, function(b) {
    x <- list(Type = "Standard", SubType = "", Description = b$id, ID = b$id,
              BlockElements = lapply(b$qs, function(p) list(Type = "Question", QuestionID = p$QuestionID)))
    if (!is.null(b$loop)) {
      x$Options <- list(Looping = "Static", LoopingOptions = list(
        Static = stats::setNames(lapply(seq_len(b$loop), function(i) list(`1` = as.character(i))),
                                 as.character(seq_len(b$loop)))))
    }
    x
  })
  flow <- lapply(seq_along(blocks), function(i)
    list(Type = "Standard", ID = blocks[[i]]$id, FlowID = paste0("FL_", i)))
  qs <- unlist(lapply(blocks, `[[`, "qs"), recursive = FALSE)
  el <- c(
    list(list(Element = "BL", PrimaryAttribute = "Survey Blocks", SecondaryAttribute = "",
              Payload = stats::setNames(bl, as.character(seq_along(bl) - 1L))),
         list(Element = "FL", PrimaryAttribute = "Survey Flow", SecondaryAttribute = "",
              Payload = list(Type = "Root", FlowID = "FL_root", Flow = flow))),
    lapply(qs, function(p) list(Element = "SQ", PrimaryAttribute = p$QuestionID,
                                SecondaryAttribute = "", Payload = p)))
  as_qsf_raw(list(SurveyEntry = list(SurveyID = "SV_lp", SurveyName = "Loop fixture"),
                  SurveyElements = el))
}
# The single path's profile as a named weight vector (names = burden).
lp_dist <- function(q, ...) {
  pr <- suppressMessages(suppressWarnings(path_burden_profile(q, ...)))
  stopifnot(nrow(pr) == 1L)
  d <- pr$profile[[1]]
  stats::setNames(d$weight / sum(d$weight), format(d$burden))
}
lp_expect <- function(got, want) {
  expect_identical(sort(as.numeric(names(got))), sort(as.numeric(names(want))))
  o <- order(as.numeric(names(got))); w <- order(as.numeric(names(want)))
  expect_equal(unname(got[o]), unname(want[w]), tolerance = 1e-9)
}


# Add a block (and its questions) that the survey flow never reaches.
lp_add_unflowed_block <- function(q, id, ...) {
  qs <- list(...)
  el <- q$SurveyElements
  bi <- which(vapply(el, function(e) identical(e$Element, "BL"), logical(1)))
  pl <- el[[bi]]$Payload
  pl[[as.character(length(pl))]] <- list(Type = "Standard", SubType = "", Description = id, ID = id,
    BlockElements = lapply(qs, function(p) list(Type = "Question", QuestionID = p$QuestionID)))
  el[[bi]]$Payload <- pl
  el <- c(el, lapply(qs, function(p) list(Element = "SQ", PrimaryAttribute = p$QuestionID,
                                         SecondaryAttribute = "", Payload = p)))
  q$SurveyElements <- el
  q
}
