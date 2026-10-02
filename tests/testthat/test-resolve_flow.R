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

test_that("an Authenticator node's nested flow is walked like a Group", {
  auth <- list(Type = "Authenticator", FlowID = "F_auth",
               Flow = list(n_block("A"), n_branch("S", n_end()), n_block("B")))
  expect_no_warning(paths <- enumerate_paths(list(auth, n_block("C"))))
  expect_setequal(paste(vapply(paths$block_ids, paste, "", collapse = ">"),
                        paths$terminates_early),
                  c("A TRUE", "A>B>C FALSE"))

  # an Authenticator with no nested flow contributes nothing
  empty <- list(Type = "Authenticator", FlowID = "F_auth")
  expect_identical(enumerate_paths(list(empty, n_block("C")))$block_ids[[1]], "C")
})

test_that("container nodes with no Flow key are empty, not their FlowID", {
  # `node$Flow` would partial-match `FlowID` and splice a string into the flow
  bare_branch <- list(Type = "Branch", FlowID = "F_br", BranchLogic = list())
  bare_group  <- list(Type = "Group", FlowID = "F_gr")
  bare_rand   <- list(Type = "BlockRandomizer", FlowID = "F_rn")
  for (node in list(bare_branch, bare_group, bare_rand)) {
    paths <- suppressWarnings(enumerate_paths(list(n_block("A"), node, n_block("B"))))
    expect_equal(nrow(paths), 1L)
    expect_identical(paths$block_ids[[1]], c("A", "B"))
  }
})

test_that("same blocks with different early-exit status stay distinct paths", {
  # taken: A, then EndSurvey with B still to come (early); not taken: A, B.
  # A second branch re-shows only A before ending -> same blocks as the first
  # early path, so it collapses into it.
  paths <- enumerate_paths(list(
    n_block("A"),
    n_branch("S1", n_end()),
    n_branch("S2", n_end()),
    n_block("B")
  ))
  expect_equal(nrow(paths), 2L)
  expect_setequal(paste(vapply(paths$block_ids, paste, "", collapse = ">"),
                        paths$terminates_early),
                  c("A TRUE", "A>B FALSE"))
})

test_that("identical block sequences from different branch routes collapse", {
  # BR1 and BR2 both add X: taking either one alone gives A>X>B, so the four
  # routes collapse to three paths.
  paths <- enumerate_paths(list(
    n_block("A"),
    n_branch("BR1", n_block("X")),
    n_branch("BR2", n_block("X")),
    n_block("B")
  ))
  seqs <- vapply(paths$block_ids, paste, "", collapse = ">")
  expect_equal(nrow(paths), 3L)
  expect_setequal(seqs, c("A>X>X>B", "A>X>B", "A>B"))
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

# --- mutually exclusive branch detection ---
n_ebranch <- function(id, field, value, ...) {
  list(
    Type = "Branch", FlowID = id,
    BranchLogic = list(
      Type = "BooleanExpression", inPage = FALSE,
      "0" = list(
        Type = "If",
        "0" = list(
          Type = "Expression",
          LogicType = "EmbeddedField",
          Operator = "EqualTo",
          LeftOperand = field,
          RightOperand = value
        )
      )
    ),
    Flow = list(...)
  )
}

test_that("extract_branch_key returns field for simple EmbeddedField EqualTo", {
  b <- n_ebranch("B1", "mode", "car")
  k <- extract_branch_key(b)
  expect_equal(k$field, "mode")
})

test_that("extract_branch_key returns NULL for Question-based or compound branches", {
  expect_null(extract_branch_key(n_branch("BR1", n_block("X"))))
  compound <- list(
    Type = "Branch", FlowID = "BR2",
    BranchLogic = list(
      Type = "BooleanExpression",
      "0" = list(
        Type = "If",
        "0" = list(Type = "Expression", LogicType = "EmbeddedField",
                   Operator = "EqualTo", LeftOperand = "f", RightOperand = "1"),
        "1" = list(Type = "Expression", LogicType = "EmbeddedField",
                   Operator = "EqualTo", LeftOperand = "f", RightOperand = "2",
                   Conjuction = "And")
      )
    ),
    Flow = list()
  )
  expect_null(extract_branch_key(compound))
  unsupported <- n_ebranch("B3", "f", "1")
  unsupported$BranchLogic[["0"]][["0"]]$Operator <- "Contains"
  expect_null(extract_branch_key(unsupported))
  expect_null(extract_branch_key(list(Type = "Branch", FlowID = "BR4")))
})

test_that("consecutive EmbeddedField branches on same field are grouped as one-of-k", {
  paths <- suppressMessages(enumerate_paths(list(
    n_block("A"),
    n_ebranch("B1", "mode", "car",  n_block("CAR")),
    n_ebranch("B2", "mode", "bus",  n_block("BUS")),
    n_ebranch("B3", "mode", "rail", n_block("RAIL")),
    n_block("Z")
  )))
  # 3 branches on same field -> 3 + 1 (none) = 4 outcomes
  expect_equal(nrow(paths), 4L)
  seqs <- vapply(paths$block_ids, paste, "", collapse = ">")
  expect_true("A>CAR>Z"  %in% seqs)
  expect_true("A>BUS>Z"  %in% seqs)
  expect_true("A>RAIL>Z" %in% seqs)
  expect_true("A>Z"      %in% seqs)  # none matches
})

test_that("exclusive group decisions record exactly one TRUE per group", {
  paths <- suppressMessages(enumerate_paths(list(
    n_ebranch("B1", "mode", "car",  n_block("CAR")),
    n_ebranch("B2", "mode", "bus",  n_block("BUS")),
    n_block("Z")
  )))
  for (i in seq_len(nrow(paths))) {
    d <- paths$decisions[[i]]
    true_count <- sum(d[c("B1", "B2")])
    expect_lte(true_count, 1L)
  }
})

test_that("branches on different fields are separate groups", {
  paths <- suppressMessages(enumerate_paths(list(
    n_ebranch("B1", "mode", "car",  n_block("CAR")),
    n_ebranch("B2", "mode", "bus",  n_block("BUS")),
    n_ebranch("B3", "route", "A",   n_block("RA")),
    n_ebranch("B4", "route", "B",   n_block("RB")),
    n_block("Z")
  )))
  # mode: 2+1=3, route: 2+1=3, cross product: 3*3=9
  expect_equal(nrow(paths), 9L)
})

test_that("a non-consecutive branch breaks the group", {
  paths <- suppressMessages(enumerate_paths(list(
    n_ebranch("B1", "mode", "car", n_block("CAR")),
    n_block("MID"),
    n_ebranch("B2", "mode", "bus", n_block("BUS")),
    n_block("Z")
  )))
  # B1 and B2 separated by a block -> not grouped -> 2 * 2 = 4 paths
  expect_equal(nrow(paths), 4L)
})

test_that("a single EmbeddedField branch is not grouped", {
  paths <- suppressMessages(enumerate_paths(list(
    n_ebranch("B1", "mode", "car", n_block("CAR")),
    n_block("Z")
  )))
  # single branch -> not grouped -> 2 paths (taken/not)
  expect_equal(nrow(paths), 2L)
})

test_that("ungroupable branch in the middle breaks the run into two groups", {
  qbranch <- n_branch("Q1", n_block("QX"))
  paths <- suppressMessages(enumerate_paths(list(
    n_ebranch("B1", "mode", "car",  n_block("CAR")),
    n_ebranch("B2", "mode", "bus",  n_block("BUS")),
    qbranch,
    n_ebranch("B3", "mode", "rail", n_block("RAIL")),
    n_ebranch("B4", "mode", "walk", n_block("WALK")),
    n_block("Z")
  )))
  # first group: mode {car,bus} -> 3 outcomes
  # Q1: 2 outcomes
  # second group: mode {rail,walk} -> 3 outcomes (same field but separated)
  expect_equal(nrow(paths), 3L * 2L * 3L)
})

# --- joint evaluation of comparisons on one field ---
n_cbranch <- function(id, field, op, value, ...) {
  b <- n_ebranch(id, field, value, ...)
  b$BranchLogic[["0"]][["0"]]$Operator <- op
  b
}

test_that("extract_branch_key returns field, operator and value for comparisons", {
  k <- extract_branch_key(n_cbranch("B1", "n", "GreaterThan", "0"))
  expect_equal(k, list(field = "n", op = "GreaterThan", value = "0"))
})

test_that("complementary > 0 and = 0 branches are never both taken", {
  flow <- list(
    n_block("A"),
    n_cbranch("OWN", "n", "GreaterThan", "0", n_block("OWNER")),
    n_cbranch("NON", "n", "EqualTo",     "0", n_block("NONOWNER")),
    n_block("Z")
  )
  paths <- suppressMessages(enumerate_paths(flow))
  seqs <- vapply(paths$block_ids, paste, "", collapse = ">")
  # any value: > 0, = 0, or negative/empty (neither) -> 3, never both
  expect_setequal(seqs, c("A>OWNER>Z", "A>NONOWNER>Z", "A>Z"))
  for (d in paths$decisions) expect_false(all(d[c("OWN", "NON")]))
})

test_that("overlapping thresholds can both be taken, in flow order", {
  flow <- list(
    n_cbranch("B1", "x", "GreaterThan", "1", n_block("GT1")),
    n_cbranch("B2", "x", "GreaterThan", "5", n_block("GT5")),
    n_block("Z")
  )
  paths <- suppressMessages(enumerate_paths(flow))
  seqs <- vapply(paths$block_ids, paste, "", collapse = ">")
  # x <= 1, 1 < x <= 5, x > 5; "only > 5" is impossible
  expect_setequal(seqs, c("Z", "GT1>Z", "GT1>GT5>Z"))
})

test_that("branch fields assigned in question JavaScript are reported", {
  qsf <- read_qsf(demo_qsf())
  flow <- list(list(Type = "Branch", FlowID = "B", Flow = list(),
                    BranchLogic = list("0" = list("0" = list(LogicType = "EmbeddedField",
                      LeftOperand = "n_cars", Operator = "GreaterThan", RightOperand = "0")))))
  qsf$SurveyElements <- c(qsf$SurveyElements, list(list(
    Element = "SQ", PrimaryAttribute = "QIDX",
    Payload = list(QuestionJS = "Qualtrics.SurveyEngine.setEmbeddedData('n_cars', 2);"))))
  js <- js_assigned_branch_fields(qsf, flow)
  expect_equal(js$field, "n_cars")
  expect_equal(js$questions, "QIDX")
  expect_equal(nrow(js_assigned_branch_fields(qsf, list())), 0L)
})

# --- integration: Zeitkostenstudie ---
test_that("Zeitkostenstudie SP gets 525 paths with exclusive branch detection", {
  skip_on_cran()
  qsf_file <- file.path(
    "C:/Users/earpkin/OneDrive - University of Leeds/Careers/surveyBurden",
    "misc/qualtrics_files/Zeitkostenstudie_2020_SP.qsf"
  )
  skip_if_not(file.exists(qsf_file), "Zeitkostenstudie QSF not available")
  qsf <- read_qsf(qsf_file)
  paths <- suppressMessages(resolve_flow(qsf))
  # 4 groups: SP_05(6), SP_67(2), SP_8(4), SP_9(4) -> (6+1)*(2+1)*(4+1)*(4+1)
  expect_equal(nrow(paths), 525L)
  expect_equal(sum(paths$terminates_early), 0L)
})

# --- integration: INFUZE Part A (owner / non-owner gates on a vehicle count) ---
test_that("INFUZE Part A: owner and non-owner blocks are never both on a path", {
  skip_on_cran()
  qsf_file <- file.path(
    "C:/Users/earpkin/OneDrive - University of Leeds/Careers/surveyBurden",
    "misc/INFUZE_CORE_SURVEY_April_2026_Part_A (3).qsf"
  )
  skip_if_not(file.exists(qsf_file), "INFUZE Part A QSF not available")
  qsf <- read_qsf(qsf_file)
  paths <- suppressMessages(resolve_flow(qsf))
  expect_equal(nrow(paths), 52L)
  expect_equal(sum(!paths$terminates_early), 24L)
  # no path shows both the owner and the non-owner blocks
  ids <- c("BL_bJC1A4335LeSSb4", "BL_9FhvpgzsEDuYw3Y")
  expect_false(any(vapply(paths$block_ids, function(b) all(ids %in% b), logical(1))))
  # the vehicle count is written by QID45's JavaScript, and is reported
  expect_message(resolve_flow(qsf), "TotalVehiclesLoop (QID45)", fixed = TRUE)
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
