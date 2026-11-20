awr_block <- function(id) list(Type = "Standard", ID = id, FlowID = paste0("FL_", id))
awr_field <- function(field, value, op = "EqualTo") list(LogicType = "EmbeddedField",
  LeftOperand = field, Operator = op, RightOperand = value)
awr_selected <- function(id, value = "1") list(LogicType = "Question", QuestionID = id,
  LeftOperand = paste0("q://", id, "/SelectableChoice/", value),
  ChoiceLocator = paste0("q://", id, "/SelectableChoice/", value), Operator = "Selected")
awr_branch <- function(id, literal, flow) list(Type = "Branch", FlowID = id,
  BranchLogic = list(Type = "BooleanExpression", `0` = list(Type = "If", `0` = literal)),
  Flow = flow)
awr_assignment <- function(value) list(Type = "EmbeddedData", FlowID = "FL_assign",
  EmbeddedData = list(list(Field = "f", Type = "Custom", Value = value)))
awr_survey <- function(flow, conditional = FALSE) {
  blocks <- c("BL0", "BLA", "BLB", "BLC")
  elements <- list(
    list(Element = "FL", Payload = list(Type = "Root", Flow = flow)),
    list(Element = "BL", Payload = lapply(seq_along(blocks), function(i)
      list(Type = "Standard", ID = blocks[i], Description = blocks[i],
        BlockElements = list(list(Type = "Question", QuestionID = paste0("QID", i)))))))
  for (i in seq_along(blocks)) {
    payload <- list(QuestionID = paste0("QID", i), QuestionType = "MC",
      Selector = "SAVR", SubSelector = "TX", QuestionText = "Choose",
      Choices = list(`1` = list(Display = "Yes"), `2` = list(Display = "No")))
    if (conditional && i == 1L) payload$DisplayLogic <-
      list(Type = "BooleanExpression", `0` = list(Type = "If", `0` = awr_field("g", "1")))
    elements[[length(elements) + 1L]] <- list(Element = "SQ", Payload = payload,
                                             PrimaryAttribute = paste0("QID", i))
  }
  as_qsf_raw(list(SurveyEntry = list(SurveyID = "SV_weights", SurveyName = "Weights"),
                  SurveyElements = elements))
}
awr_components <- function(q, weights, complete = FALSE) {
  paths <- suppressMessages(resolve_paths(q))
  blocks <- resolve_live_blocks(q)
  scored <- score_burden(parse_qsf(q))
  ctx <- traversal_context(q, scored, blocks, list(), TRUE)
  selected <- if (complete) which(!paths$terminates_early) else seq_len(nrow(paths))
  components <- suppressMessages(answer_weight_routes(q, ctx, paths, selected, weights))
  keys <- vapply(paths$block_ids, paste, character(1), collapse = ">")
  list(components = components, paths = paths, keys = keys)
}
awr_mass <- function(result) {
  components <- result$components
  tapply(vapply(components, `[[`, numeric(1), "mass"),
    vapply(components, function(component) result$keys[component$path_index], character(1)), sum)
}

test_that("merged route histories receive the sum of their assignment masses", {
  q <- awr_survey(list(awr_block("BL0"),
    awr_branch("F1", awr_field("f", "1"), list(awr_block("BLA"))),
    awr_branch("F2", awr_field("f", "2"), list(awr_block("BLA")))))
  result <- awr_components(q, list(`@f` = c(`1` = .2, `2` = .3, `3` = .5)))
  expect_equal(unname(awr_mass(result)["BL0>BLA"]), .5)
  expect_equal(unname(awr_mass(result)["BL0"]), .5)
  expect_equal(sum(awr_mass(result)), 1)
})

test_that("repeated weighted question tests share the same assignment", {
  q <- awr_survey(list(awr_block("BL0"),
    awr_branch("F1", awr_selected("QID1"), list(awr_block("BLA"))),
    awr_branch("F2", awr_selected("QID1"), list(awr_block("BLB")))))
  result <- awr_components(q, list(QID1 = c(`1` = .8, `2` = .2)))
  expect_equal(unname(awr_mass(result)["BL0>BLA>BLB"]), .8)
  expect_equal(unname(awr_mass(result)["BL0"]), .2)
  expect_length(awr_mass(result), 2L)
  expect_true(all(vapply(result$components, function(component)
    component$fixed$QID1 %in% c("1", "2"), logical(1))))
})

test_that("fixed fields override initial assumptions before any block", {
  q <- awr_survey(list(awr_assignment("2"), awr_block("BL0"),
    awr_branch("F1", awr_field("f", "1"), list(awr_block("BLA"))),
    awr_branch("F2", awr_field("f", "2"), list(awr_block("BLB")))))
  result <- awr_components(q, list(`@f` = c(`1` = .9, `2` = .1)))
  expect_equal(unname(awr_mass(result)["BL0>BLB"]), 1)
  expect_true(all(vapply(result$components, function(component)
    identical(component$fixed$`@f`, "2"), logical(1))))
})

test_that("unspecified branches retain equal distinct residual route weights", {
  q <- awr_survey(list(awr_block("BL0"),
    awr_branch("F1", awr_field("f", "1"), list(awr_block("BLA"))),
    awr_branch("F2", awr_field("g", "1"), list(awr_block("BLB")))))
  result <- awr_components(q, list(`@f` = c(`1` = .8, `2` = .2)))
  expect_equal(as.numeric(awr_mass(result)[c("BL0>BLA>BLB", "BL0>BLA")]), c(.4, .4))
  expect_equal(as.numeric(awr_mass(result)[c("BL0>BLB", "BL0")]), c(.1, .1))
})

test_that("empty field states and zero-weight labels integrate correctly", {
  q <- awr_survey(list(awr_block("BL0"),
    awr_branch("F1", awr_field("f", "1"), list(awr_block("BLA")))))
  result <- awr_components(q, list(`@f` = stats::setNames(c(.4, .6, 0), c("", "1", "2"))))
  expect_equal(as.numeric(awr_mass(result)["BL0"]), .4)
  expect_equal(as.numeric(awr_mass(result)["BL0>BLA"]), .6)
  expect_length(result$components, 2L)
})

test_that("non-routing weights leave route masses alone", {
  q <- awr_survey(list(awr_block("BL0"),
    awr_branch("F1", awr_field("f", "1"), list(awr_block("BLA")))))
  result <- awr_components(q, list(QID1 = c(`1` = .9, `2` = .1)))
  expect_equal(as.numeric(awr_mass(result)), rep(.5, 2L))
  expect_true(all(vapply(result$components, function(component)
    length(component$fixed) == 0L, logical(1))))
})

test_that("randomisers retain the residual equal-route convention", {
  randomiser <- list(Type = "BlockRandomizer", FlowID = "FL_random", SubSet = 1L,
    Flow = list(awr_block("BLB"), awr_block("BLC")))
  q <- awr_survey(list(awr_block("BL0"),
    awr_branch("F1", awr_field("f", "1"), list(awr_block("BLA"))), randomiser))
  result <- awr_components(q, list(`@f` = c(`1` = .8, `2` = .2)))
  expect_equal(as.numeric(awr_mass(result)[c("BL0>BLA>BLB", "BL0>BLA>BLC")]), c(.4, .4))
  expect_equal(as.numeric(awr_mass(result)[c("BL0>BLB", "BL0>BLC")]), c(.1, .1))
})

test_that("completion filtering preserves unnormalised scenario probability", {
  q <- awr_survey(list(awr_block("BL0"), awr_branch("F1", awr_field("f", "1"),
    list(list(Type = "EndSurvey", FlowID = "FL_end"))), awr_block("BLA")))
  result <- awr_components(q, list(`@f` = c(`1` = .8, `2` = .2)), complete = TRUE)
  expect_equal(sum(awr_mass(result)), .2)
})

test_that("unsupported weighted routing fails explicitly", {
  q <- awr_survey(list(awr_block("BL0"),
    awr_branch("F1", awr_selected("QID1"), list(awr_block("BLA")))), conditional = TRUE)
  expect_error(awr_components(q, list(QID1 = c(`1` = 1))), "conditional")
  q <- awr_survey(list(awr_block("BL0"), awr_assignment("2"),
    awr_branch("F1", awr_field("f", "1"), list(awr_block("BLA")))))
  expect_error(awr_components(q, list(`@f` = c(`1` = 1))), "after a block")
  q <- awr_survey(list(awr_assignment("${q://QID1/ChoiceGroup/SelectedChoices}"),
    awr_branch("F1", awr_field("f", "1"), list(awr_block("BLA")))))
  expect_error(awr_components(q, list(`@f` = c(`1` = 1))), "piped")
  literal <- awr_field("f", "x", "Contains")
  q <- awr_survey(list(awr_branch("F1", literal, list(awr_block("BLA")))))
  expect_error(awr_components(q, list(`@f` = c(x = 1))), "unsupported operator")
})
