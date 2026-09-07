qsf_fixture <- function() read_qsf(demo_qsf())

test_that("resolve_live_blocks returns one row per flow-reachable block, Trash excluded", {
  blocks <- resolve_live_blocks(qsf_fixture())

  expect_s3_class(blocks, "tbl_df")
  expect_setequal(names(blocks), c(
    "flow_order", "block_id", "block_name",
    "in_loop", "loop_on_qid", "loop_max", "question_ids"
  ))
  expect_equal(nrow(blocks), 12L)
  expect_false("Bin/Unused" %in% blocks$block_name)
  expect_true(all(c("Welcome", "About you", "Consent") %in% blocks$block_name))
})

test_that("resolve_live_blocks preserves flow order without gaps", {
  blocks <- resolve_live_blocks(qsf_fixture())
  expect_identical(blocks$flow_order, seq_len(nrow(blocks)))
})

test_that("resolve_live_blocks lists the questions in each block, 26 in total", {
  blocks <- resolve_live_blocks(qsf_fixture())

  expect_type(blocks$question_ids, "list")
  expect_equal(sum(lengths(blocks$question_ids)), 26L)
  expect_true(all(grepl("^QID", unlist(blocks$question_ids))))
})

test_that("resolve_live_blocks flags Loop & Merge blocks with their bound", {
  blocks <- resolve_live_blocks(qsf_fixture())

  adults <- blocks[blocks$block_name == "Other adults", ]
  expect_true(adults$in_loop)
  expect_identical(adults$loop_on_qid, "QID9")
  expect_identical(adults$loop_max, 5L)

  vehicles <- blocks[blocks$block_name == "Vehicle details", ]
  expect_true(vehicles$in_loop)
  expect_identical(vehicles$loop_on_qid, "QID15")
  expect_identical(vehicles$loop_max, 3L)

  # a non-looping block
  consent <- blocks[blocks$block_name == "Consent", ]
  expect_false(consent$in_loop)
  expect_true(is.na(consent$loop_on_qid))
  expect_true(is.na(consent$loop_max))
})
