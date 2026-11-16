# Figures the JSS paper reports for its two applications (Sections 6 and 7),
# from surveyBurden 0.3.0. The survey files are not distributed with the
# package, so these tests run only where they are available. If a change moves
# any of these numbers, the paper must be updated to match.

published_file <- function(...) {
  file.path("C:/Users/earpkin/OneDrive - University of Leeds/Careers/surveyBurden",
            "misc/qualtrics_files", ...)
}

test_that("the Zeitkostenstudie report gives the published figures", {
  skip_on_cran()
  f <- published_file("Zeitkostenstudie_2020_SP.qsf")
  skip_if_not(file.exists(f), "Zeitkostenstudie QSF not available")
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
  skip_if_not(file.exists(qsf) && file.exists(csv), "Swiss Mobility Panel files not available")
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
