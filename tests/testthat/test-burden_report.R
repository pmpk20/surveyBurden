fx <- function() demo_qsf()

report_naive <- local({
  v <- NULL
  function() { if (is.null(v)) v <<- burden_report(fx(), profile = FALSE, certainty = FALSE); v }
})
report_full <- local({
  v <- NULL
  function() { if (is.null(v)) v <<- burden_report(fx(), certainty = FALSE); v }
})






test_that("$burden matches the pre-refactor structural range (value parity)", {
  r <- report_full()
  # 103/114/120/126 (were 106/117/123/130) since display logic inside Loop &
  # Merge blocks is evaluated: the demo's loop questions QID13 and QID17 are
  # conditional and were counted as always shown in every iteration
  expect_equal(bstat(r, "min"), 103)
  expect_equal(bstat(r, "p25"), 114)
  expect_equal(bstat(r, "median"), 120)
  # 130 (was 129) since And If binds before Else If: the demo's QID22
  # (If employed / Else If self-employed / And If not fully remote) shows more
  expect_equal(bstat(r, "p75"), 126)
  expect_equal(bstat(r, "max"), 143)
})









# finishers on the demo survey answering different numbers of questions
report_responses <- function(n = 40) {
  cat_ <- parse_qsf(read_qsf(fx()))
  qids <- cat_$question_id[!cat_$in_loop]
  set.seed(3)
  obs <- data.frame(ResponseId = paste0("R_", seq_len(n)),
                    Finished = c(rep("1", n - 2), "0", "0"))
  k <- sample(5:length(qids), n, TRUE)
  for (j in seq_along(qids)) obs[[qids[j]]] <- ifelse(j <= k, "1", NA)
  obs
}









# a survey where every value of a panel field leads to an end of survey: every
# route ends early, so there is no complete route to summarise a spread over
no_complete_qsf <- function() {
  q <- read_qsf(demo_qsf())
  fl <- which(vapply(q$SurveyElements,
                     function(e) identical(e$Element, "FL"), logical(1)))
  screen <- function(v) list(Type = "Branch", FlowID = paste0("F_scr", v),
                             Description = "screen", BranchLogic = fg_logic(fg_emb("grp", "EqualTo", v)),
                             Flow = list(list(Type = "EndSurvey", FlowID = paste0("F_end", v))))
  q$SurveyElements[[fl]]$Payload$Flow <- c(
    list(screen("1"), screen("2")),
    q$SurveyElements[[fl]]$Payload$Flow
  )
  q
}

test_that("burden_report degrades gracefully when no path completes", {
  q <- no_complete_qsf()

  expect_no_error(r <- burden_report(q, certainty = FALSE, quiet = TRUE,
                                     field_domains = list(grp = c("1", "2"))))
  expect_s3_class(r, "burden_report")
  expect_equal(r$survey$n_complete_paths, 0L)
  expect_true(all(is.na(r$burden$points)))
  expect_equal(attr(r$burden, "basis"), "none")
  expect_match(paste(r$warnings, collapse = " "),
               "No route is complete", ignore.case = TRUE)
  expect_no_error(format(r))
  expect_no_error(capture.output(print(summary(r))))
})

test_that("a survey that ends before any block gives a clear error", {
  q <- read_qsf(demo_qsf())
  fl <- which(vapply(q$SurveyElements,
                     function(e) identical(e$Element, "FL"), logical(1)))
  q$SurveyElements[[fl]]$Payload$Flow <- c(
    list(list(Type = "EndSurvey", FlowID = "F_kill")),
    q$SurveyElements[[fl]]$Payload$Flow)
  expect_error(suppressMessages(burden_report(q, quiet = TRUE)), "ends before any block")
})



# --- verdict line ----------------------------------------------------------







test_that("the verdict names the median respondent burden when responses are given", {
  r <- burden_report(fx(), responses = report_responses(), certainty = FALSE, quiet = TRUE)
  expect_true(any(grepl("Median respondent burden", format(r), fixed = TRUE)))
  expect_match(summary_line(r), "Median respondent burden")
})






test_that("printed output uses plain words, not the old jargon", {
  r <- burden_report(fx(), quiet = TRUE)
  txt <- paste(format(r), collapse = "\n")
  expect_match(txt, "Routes: ")
  expect_match(txt, "Questions that control display logic")
  for (w in c("structural", "trigger", "convolved", "primary-gate", "enumerated", "path"))
    expect_false(grepl(w, txt, ignore.case = TRUE), info = w)
  cc <- paste(format(calculation_certainty(read_qsf(demo_qsf()))), collapse = "\n")
  expect_match(cc, "2 complete routes", fixed = TRUE)
  expect_match(cc, "None was approximated.", fixed = TRUE)
  expect_match(cc, "Other adults: 0 to 5 repetitions", fixed = TRUE)
  expect_match(cc, "19 items scored automatically, 7 by inference, 0 from user input, 0 unscored.", fixed = TRUE)
})
