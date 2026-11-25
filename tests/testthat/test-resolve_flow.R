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
  expect_error(enumerate_paths(many, max_paths = 500), "too many routes")
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

test_that("blocks after a top-level end of survey are left out, not read as early exits", {
  q <- read_qsf(demo_qsf())
  base <- burden_report(q, quiet = TRUE)
  i <- which(vapply(q$SurveyElements, function(e) identical(e$Element, "FL"), logical(1)))
  fl <- q$SurveyElements[[i]]$Payload$Flow
  stray <- Find(function(n) is.list(n) && n$Type %in% c("Standard", "Block"), fl)
  q$SurveyElements[[i]]$Payload$Flow <- c(fl, list(n_end(), stray))

  rep <- suppressMessages(burden_report(q, quiet = TRUE))
  expect_equal(rep$burden$points, base$burden$points)
  expect_equal(rep$survey$n_complete_paths, base$survey$n_complete_paths)
  expect_true(any(grepl("after the end of the survey", rep$warnings)))
  expect_equal(surveyBurden:::blocks_after_end(q), stray$ID)
  expect_length(surveyBurden:::blocks_after_end(read_qsf(demo_qsf())), 0L)
})
