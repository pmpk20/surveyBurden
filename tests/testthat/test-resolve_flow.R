# --- synthetic flow-node builders ---
n_block  <- function(id) list(Type = "Standard", ID = id, FlowID = paste0("F_", id))
n_ed     <- function() list(Type = "EmbeddedData", FlowID = "F_ed", EmbeddedData = list())
n_end    <- function() list(Type = "EndSurvey", FlowID = "F_end")
n_branch <- function(id, ...) list(Type = "Branch", FlowID = id, Description = "if X",
                                   BranchLogic = list(), Flow = list(...))

test_that("a flow with no branches yields exactly one path", {
  paths <- enumerate_paths(list(n_block("A"), n_block("B"), n_block("C")))

  expect_s3_class(paths, "tbl_df")
  expect_equal(nrow(paths), 1L)
  expect_identical(paths$block_ids[[1]], c("A", "B", "C"))
  expect_false(paths$terminates_early[[1]])
})

test_that("embedded-data nodes do not affect the block sequence", {
  paths <- enumerate_paths(list(n_block("A"), n_ed(), n_block("B")))
  expect_equal(nrow(paths), 1L)
  expect_identical(paths$block_ids[[1]], c("A", "B"))
})

test_that("a branch forks into taken and not-taken paths", {
  paths <- enumerate_paths(list(
    n_block("A"),
    n_branch("BR1", n_block("X")),
    n_block("B")
  ))

  expect_equal(nrow(paths), 2L)
  expect_setequal(
    lapply(paths$block_ids, identity),
    list(c("A", "X", "B"), c("A", "B"))
  )
})

test_that("EndSurvey inside a taken branch terminates that path early", {
  paths <- enumerate_paths(list(
    n_block("A"),
    n_branch("SCREEN", n_end()),
    n_block("B"), n_block("C")
  ))

  early <- paths[paths$terminates_early, ]
  full  <- paths[!paths$terminates_early, ]
  expect_identical(early$block_ids[[1]], "A")
  expect_identical(full$block_ids[[1]], c("A", "B", "C"))
})

test_that("branches with no block effect collapse to one path", {
  paths <- enumerate_paths(list(
    n_block("A"),
    n_branch("SRC", n_ed()),      # taken or not, same blocks
    n_block("B")
  ))
  expect_equal(nrow(paths), 1L)
  expect_identical(paths$block_ids[[1]], c("A", "B"))
})

test_that("branch decisions are recorded per path", {
  paths <- enumerate_paths(list(n_branch("BR1", n_block("X")), n_block("B")))
  taken <- paths[vapply(paths$block_ids, function(b) "X" %in% b, logical(1)), ]
  expect_true(taken$decisions[[1]][["BR1"]])
})

test_that("path explosion is capped with a clear error", {
  many <- c(
    lapply(1:20, function(i) n_branch(paste0("BR", i), n_block(paste0("X", i)))),
    list(n_block("END"))
  )
  expect_error(enumerate_paths(many, max_paths = 500), "path space")
})

# --- integration: the demo travel survey flow ---
test_that("resolve_flow enumerates plausible paths for the demo survey", {
  qsf <- read_qsf(demo_qsf())
  paths <- resolve_flow(qsf)

  expect_s3_class(paths, "tbl_df")
  expect_true(all(c("path_id", "block_ids", "terminates_early", "decisions") %in% names(paths)))
  expect_gt(nrow(paths), 1L)
  expect_lt(nrow(paths), 2000L)

  live_ids <- resolve_live_blocks(qsf)$block_id
  expect_true(all(unlist(paths$block_ids) %in% live_ids))

  # at least one screen-out and a spread of path lengths
  expect_true(any(paths$terminates_early))
  lens <- lengths(paths$block_ids)
  expect_gt(max(lens), min(lens))
})
