# --- synthetic flow-node builders ---
n_block  <- function(id) list(Type = "Standard", ID = id, FlowID = paste0("F_", id))
n_ed     <- function() list(Type = "EmbeddedData", FlowID = "F_ed", EmbeddedData = list())
n_end    <- function() list(Type = "EndSurvey", FlowID = "F_end")
n_branch <- function(id, ...) list(Type = "Branch", FlowID = id, Description = "if X",
                                   BranchLogic = list(), Flow = list(...))



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






# --- joint evaluation of comparisons on one field ---
n_cbranch <- function(id, field, op, value, ...) {
  b <- n_ebranch(id, field, value, ...)
  b$BranchLogic[["0"]][["0"]]$Operator <- op
  b
}


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
  # declared exhaustive: no "none matches" path, 6 * 2 * 4 * 4
  dom <- list(SP_05 = 0:5, SP_67 = 6:7, SP_8 = c(8, 88, 888, 8888), SP_9 = c(9, 99, 999, 9999))
  expect_equal(nrow(suppressMessages(resolve_flow(qsf, field_domains = dom))), 192L)
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


test_that("a web-service call shows nothing and is noted only when it sets fields", {
  ping <- list(Type = "WebService", FlowID = "F_ws", URL = "https://example.org",
               FireAndForget = TRUE, ResponseMap = list())
  expect_no_warning(expect_no_message(
    paths <- enumerate_paths(list(n_block("A"), ping, n_block("B")))))
  expect_identical(paths$block_ids[[1]], c("A", "B"))

  setter <- ping; setter$ResponseMap <- list(list(key = "score", value = "$.score"))
  expect_message(enumerate_paths(list(n_block("A"), setter)), "web-service call")
})
