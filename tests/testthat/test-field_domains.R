# Field values along a path (L1). A branch field holds one value along a path:
# every branch on it agrees with that value, a fixed value set in the flow
# decides later branches, and `field_domains` limits a field to declared
# values, so a "none matches" fallback is enumerated only when some declared
# value matches no branch. Synthetic survey: one yes/no question per block.

fd_mc <- function(qid) {
  list(QuestionID = qid, QuestionType = "MC", Selector = "SAVR", SubSelector = "TX",
       QuestionText = "Yes or no?", DataExportTag = qid, QuestionDescription = qid,
       Choices = list(`1` = list(Display = "Yes"), `2` = list(Display = "No")))
}
fd_qsf <- function(flow, blocks = c("BL0", "BLA", "BLB", "BLC", "BLD", "BLM")) {
  qids <- paste0("Q", blocks)
  bl <- lapply(seq_along(blocks), function(i)
    list(Type = "Standard", SubType = "", Description = blocks[i], ID = blocks[i],
         BlockElements = list(list(Type = "Question", QuestionID = qids[i]))))
  el <- c(
    list(list(Element = "BL", PrimaryAttribute = "Survey Blocks", SecondaryAttribute = "",
              Payload = stats::setNames(bl, as.character(seq_along(bl) - 1L))),
         list(Element = "FL", PrimaryAttribute = "Survey Flow", SecondaryAttribute = "",
              Payload = list(Type = "Root", FlowID = "FL_root", Flow = flow))),
    lapply(qids, function(q) list(Element = "SQ", PrimaryAttribute = q,
                                  SecondaryAttribute = "", Payload = fd_mc(q))))
  as_qsf_raw(list(SurveyEntry = list(SurveyID = "SV_fd", SurveyName = "Field domains"),
                  SurveyElements = el))
}
fd_blk <- function(id) list(Type = "Standard", ID = id, FlowID = paste0("FL_", id))
fd_br <- function(fid, field, value, block, op = "EqualTo") {
  list(Type = "Branch", FlowID = fid, Description = "",
       BranchLogic = list(`0` = list(`0` = list(
         LogicType = "EmbeddedField", LeftOperand = field, Operator = op,
         RightOperand = value, Type = "Expression", Description = ""), Type = "If"),
         Type = "BooleanExpression"),
       Flow = list(fd_blk(block)))
}
fd_ed <- function(fid, field, value, type = "Custom") {
  list(Type = "EmbeddedData", FlowID = fid,
       EmbeddedData = list(list(Description = field, Type = type, Field = field,
                                VariableType = "String", DataVisibility = list(),
                                Value = value)))
}
fd_seqs <- function(q, ...) {
  f <- suppressMessages(resolve_flow(q, ...))
  sort(vapply(f$block_ids, paste, "", collapse = ">"))
}

# BL0, then f == 1 -> BLA, f == 2 -> BLB
one_group <- function() list(fd_blk("BL0"), fd_br("FL_1", "f", "1", "BLA"),
                             fd_br("FL_2", "f", "2", "BLB"))

test_that("without a domain the none-matches fallback is kept", {
  expect_equal(fd_seqs(fd_qsf(one_group())), sort(c("BL0>BLA", "BL0>BLB", "BL0")))
})

test_that("a declared domain drops the fallback when every value matches a branch", {
  q <- fd_qsf(one_group())
  expect_equal(fd_seqs(q, field_domains = list(f = c("1", "2"))),
               sort(c("BL0>BLA", "BL0>BLB")))
  # numbers are accepted and compared as text
  expect_equal(fd_seqs(q, field_domains = list(f = 1:2)), sort(c("BL0>BLA", "BL0>BLB")))
})

test_that("a declared value that matches no branch keeps the fallback", {
  expect_equal(fd_seqs(fd_qsf(one_group()), field_domains = list(f = c("1", "3"))),
               sort(c("BL0>BLA", "BL0")))
})

test_that("a domain also settles a single branch", {
  flow <- list(fd_blk("BL0"), fd_br("FL_1", "f", "1", "BLA"))
  expect_equal(fd_seqs(fd_qsf(flow), field_domains = list(f = "1")), "BL0>BLA")
})

test_that("branches on one field agree along a path, even when not adjacent", {
  # f == 1 -> BLA, f == 2 -> BLB; BLM; f == 1 -> BLC, f == 2 -> BLD
  flow <- list(fd_br("FL_1", "f", "1", "BLA"), fd_br("FL_2", "f", "2", "BLB"),
               fd_blk("BLM"),
               fd_br("FL_3", "f", "1", "BLC"), fd_br("FL_4", "f", "2", "BLD"))
  expect_equal(fd_seqs(fd_qsf(flow)), sort(c("BLA>BLM>BLC", "BLB>BLM>BLD", "BLM")))
})

test_that("a fixed value set in the flow decides later branches", {
  flow <- c(list(fd_ed("FL_e", "f", "2")), one_group())
  expect_equal(fd_seqs(fd_qsf(flow)), "BL0>BLB")
})

test_that("a later reassignment is followed", {
  flow <- list(fd_ed("FL_e1", "f", "1"),
               fd_br("FL_1", "f", "1", "BLA"), fd_br("FL_2", "f", "2", "BLB"),
               fd_ed("FL_e2", "f", "2"),
               fd_br("FL_3", "f", "1", "BLC"), fd_br("FL_4", "f", "2", "BLD"))
  expect_equal(fd_seqs(fd_qsf(flow)), "BLA>BLD")
})

test_that("a piped value makes the field unknown again", {
  flow <- c(list(fd_ed("FL_e1", "f", "1"), fd_ed("FL_e2", "f", "${q://QID1/ChoiceGroup/SelectedChoices}")),
            one_group())
  expect_equal(fd_seqs(fd_qsf(flow)), sort(c("BL0>BLA", "BL0>BLB", "BL0")))
})

test_that("a declaration without a value (panel or URL field) leaves the field free", {
  flow <- c(list(fd_ed("FL_e", "f", "", type = "Recipient")), one_group())
  expect_equal(fd_seqs(fd_qsf(flow)), sort(c("BL0>BLA", "BL0>BLB", "BL0")))
})

test_that("a randomiser assigning the field gives one path per assigned value", {
  rand <- list(Type = "BlockRandomizer", FlowID = "FL_r", SubSet = 1L, EvenPresentation = TRUE,
               Flow = list(fd_ed("FL_r1", "f", "1"), fd_ed("FL_r2", "f", "2"),
                           fd_ed("FL_r3", "f", "1")))
  flow <- c(list(rand), one_group())
  expect_equal(fd_seqs(fd_qsf(flow)), sort(c("BL0>BLA", "BL0>BLB")))
})

test_that("field_domains is validated", {
  q <- fd_qsf(one_group())
  expect_error(resolve_flow(q, field_domains = list("1")), "named")
  expect_error(resolve_flow(q, field_domains = list(f = character(0))), "f")
  expect_warning(suppressMessages(resolve_flow(q, field_domains = list(g = "1"))), "g")
})

test_that("burden_report() and path_burden() pass field_domains through", {
  q <- fd_qsf(one_group())
  r <- suppressMessages(burden_report(q, quiet = TRUE, field_domains = list(f = c("1", "2"))))
  expect_equal(nrow(r$paths), 2L)
  pb <- suppressMessages(path_burden(q, field_domains = list(f = c("1", "2"))))
  expect_equal(nrow(pb), 2L)
})
