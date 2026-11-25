# Integration tests on survey files that are not distributed with the
# package. They run only where the files are available: set
# SURVEYBURDEN_DATA_DIR to the folder holding the Zeitkostenstudie and Swiss
# Mobility Panel files, and SURVEYBURDEN_GATE_QSF to the full path of a survey
# with owner / non-owner gates on a vehicle count. This file is left out of the
# CRAN build (.Rbuildignore).
#
# The first two tests hold the figures the JSS paper reports for its two
# applications. If a change moves any of these numbers, the paper must be
# updated to match.

published_file <- function(...) {
  dir <- Sys.getenv("SURVEYBURDEN_DATA_DIR")
  if (!nzchar(dir)) return(NA_character_)
  file.path(dir, ...)
}
available <- function(f) !is.na(f) && nzchar(f) && file.exists(f)

test_that("the Zeitkostenstudie report gives the published figures", {
  skip_on_cran()
  f <- published_file("Zeitkostenstudie_2020_SP.qsf")
  skip_if_not(available(f), "Zeitkostenstudie QSF not available")
  q <- read_qsf(f)
  tasks <- suggest_choice_tasks(q)
  n_attributes <- c(Verkehrsmittelwahl = 6, Routenwahl = 5, Wohnortwahl = 10,
                    Arbeitsplatzwahl = 4)
  tasks$n_attributes <- n_attributes[tasks$block_name]
  domains <- list(SP_05 = 0:5, SP_67 = 6:7, SP_8 = c(8, 88, 888, 8888),
                  SP_9 = c(9, 99, 999, 9999))
  r <- suppressMessages(burden_report(q, quiet = TRUE, choice_tasks = tasks,
                                      field_domains = domains))
  expect_equal(r$survey$n_questions, 73L)
  expect_equal(nrow(r$paths), 192L)
  expect_equal(sum(r$blocks$gfs_points), 618)
  expect_equal(r$burden$points, c(386, 390, 391, 393, 396))
})

test_that("the Swiss Mobility Panel figures match the published values", {
  skip_on_cran()
  qsf <- published_file("Swiss_Mobility_Panel_W4.qsf")
  csv <- published_file("Swiss_Mobility_Panel_W4_February 9, 2023_15.23-stripped-copy.csv")
  skip_if_not(available(qsf) && available(csv), "Swiss Mobility Panel files not available")
  tasks <- data.frame(question_id = "QID268", n_alternatives = 2, n_attributes = 4)
  r <- suppressMessages(burden_report(qsf, quiet = TRUE, max_condition_states = 100000,
                                      choice_tasks = tasks))
  expect_equal(sum(r$paths$status == "complete"), 9L)
  expect_equal(r$burden$points, c(298, 391, 431, 487, 690))
  rb <- suppressMessages(respondent_burden(qsf, csv, choice_tasks = tasks))
  expect_equal(nrow(rb), 8630L)
  done <- rb$points[rb$outcome == "complete"]
  expect_equal(length(done), 8444L)
  expect_equal(unname(stats::quantile(done, c(.25, .5, .75), type = 1)), c(455, 486, 504))
})


# --- integration: Zeitkostenstudie ---
test_that("Zeitkostenstudie SP gets 525 paths with exclusive branch detection", {
  skip_on_cran()
  qsf_file <- published_file("Zeitkostenstudie_2020_SP.qsf")
  skip_if_not(available(qsf_file), "Zeitkostenstudie QSF not available")
  qsf <- read_qsf(qsf_file)
  paths <- suppressMessages(resolve_flow(qsf))
  # 4 groups: SP_05(6), SP_67(2), SP_8(4), SP_9(4) -> (6+1)*(2+1)*(4+1)*(4+1)
  expect_equal(nrow(paths), 525L)
  expect_equal(sum(paths$terminates_early), 0L)
  # declared exhaustive: no "none matches" path, 6 * 2 * 4 * 4
  dom <- list(SP_05 = 0:5, SP_67 = 6:7, SP_8 = c(8, 88, 888, 8888), SP_9 = c(9, 99, 999, 9999))
  expect_equal(nrow(suppressMessages(resolve_flow(qsf, field_domains = dom))), 192L)
})

# --- integration: owner / non-owner gates on a vehicle count ---
test_that("vehicle-gate survey: owner and non-owner blocks are never both on a route", {
  skip_on_cran()
  qsf_file <- Sys.getenv("SURVEYBURDEN_GATE_QSF")
  skip_if_not(available(qsf_file), "vehicle-gate survey QSF not available")
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
