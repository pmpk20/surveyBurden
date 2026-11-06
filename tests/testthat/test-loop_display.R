# Display logic inside Loop & Merge blocks: the iteration-position gate,
# gate classification, and the loop-aware structural profile.

lp_pos_logic <- function(block = "BL_x", k = 1, op = "EqualTo") {
  list(`0` = list(`0` = list(LogicType = "LoopAndMerge",
                             LeftOperand = paste0(block, ",", k), Operator = op,
                             RightOperand = "lm://CurrentLoop", Type = "Expression"),
                  Type = "If"),
       Type = "BooleanExpression", inPage = FALSE)
}

test_that("LoopAndMerge CurrentLoop literal becomes the @@iter gate", {
  p <- parse_display_logic(lp_pos_logic())
  expect_identical(p$vars, "@@iter")
  expect_true(p$predicate(list("@@iter" = 1L)))
  expect_false(p$predicate(list("@@iter" = 2L)))
  # outside a loop Qualtrics leaves lm://CurrentLoop empty: never shown
  expect_false(p$predicate(list()))
  # the literal reads "Loop k <op> Current Loop": op(k, current)
  expect_true(parse_display_logic(lp_pos_logic(op = "LessThan"))$predicate(list("@@iter" = 3L)))
  expect_false(parse_display_logic(lp_pos_logic(op = "GreaterThan"))$predicate(list("@@iter" = 3L)))
  expect_identical(parse_display_logic(lp_pos_logic(block = "BL_q"))$loop_blocks, "BL_q")
})
