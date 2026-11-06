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
