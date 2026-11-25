# Declared stated-choice tasks (`choice_tasks =`), scored by the GfS
# stated-choice rows: sc_2_alt / sc_3_alt (1.0 per alternative beyond three)
# plus sc_per_variable per attribute. On the synthetic exposure fixture, QID1
# (two options, on every path) scores 1.0 as a closed yes/no; declared as a
# 2-alternative, 4-attribute task it scores 6.0, so every path gains 5.

ct_qsf <- function() read_qsf(test_path("fixtures", "exposure_fixture.qsf"))
ct <- function(qid = "QID1", alts = 2L, attrs = 4L) {
  data.frame(question_id = qid, n_alternatives = alts, n_attributes = attrs)
}
ct_scored <- function() score_burden(parse_qsf(ct_qsf()))
pts <- function(sc, qid) sc$gfs_points[sc$question_id == qid]

# same five respondents as test-respondent_burden.R (only what is needed here)
ct_responses <- function() {
  data.frame(
    ResponseId = paste0("R", 1:5),
    Finished   = c(1, 1, 0, 0, 1),
    Mode       = c("web", "web", "phone", "web", "phone"),
    LastBlock  = c(NA, NA, "BL3", "Driving", NA),
    QID1       = c("1", "2", "1", "1", "1"),
    QID2       = c("2", NA, "3", "0", "1"),
    QID3_1     = c("1", NA, NA, NA, "1"),
    QID3_2     = c(NA, NA, "1", NA, NA),
    QID3_3     = c(NA, NA, NA, NA, NA),
    QID4       = c("1", NA, NA, NA, "2"),
    `1_QID5`   = c("1", NA, "2", NA, "3"),
    `1_QID6`   = c("2", NA, NA, NA, "1"),
    `1_QID7`   = c("1", NA, "1", NA, "1"),
    `2_QID5`   = c("2", NA, "1", NA, NA),
    `2_QID6`   = c(NA, NA, NA, NA, NA),
    `3_QID5`   = c(NA, NA, NA, NA, NA),
    QID8       = c("friend", NA, NA, NA, NA),
    QID9       = c("2", NA, NA, NA, NA),
    QID10      = c(NA, NA, NA, NA, "1"),
    QID12      = c(NA, NA, NA, NA, "2"),
    QID13      = c("1", NA, NA, NA, "3"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
}


test_that("a declared 2-alternative, 4-attribute task scores 6.0; undeclared stays 1.0", {
  sc <- ct_scored()
  expect_equal(pts(sc, "QID1"), 1)
  out <- score_choice_tasks(sc, ct())
  expect_equal(pts(out, "QID1"), 6)
  row <- out[out$question_id == "QID1", ]
  expect_equal(row$score_flag, "manual")
  expect_match(row$score_basis, "stated choice")
  expect_match(row$score_basis, "4 attributes")
  other <- out$question_id != "QID1"
  expect_equal(out[other, ], sc[other, ])
  expect_identical(score_choice_tasks(sc, NULL), sc)
})

test_that("three alternatives use sc_3_alt; more add 1.0 each beyond three", {
  sc <- ct_scored()
  expect_equal(pts(score_choice_tasks(sc, ct(alts = 3L, attrs = 2L)), "QID1"), 3 + 2)
  big <- score_choice_tasks(sc, ct(alts = 5L, attrs = 3L))
  expect_equal(pts(big, "QID1"), 5 + 3)
  expect_match(big$score_basis[big$question_id == "QID1"], "beyond GfS\\+ Table 1")
  # the rates come from the scheme
  s <- gfs_scheme(); s$sc_per_variable <- 0.5; s$sc_per_extra_alt <- 2
  expect_equal(pts(score_choice_tasks(sc, ct(alts = 4L, attrs = 2L), s), "QID1"),
               3 + 2 + 1)
})

test_that("several tasks are scored in one call", {
  sc <- score_choice_tasks(ct_scored(),
                           data.frame(question_id = c("QID1", "QID4"),
                                      n_alternatives = c(2, 3),
                                      n_attributes = c(4, 0)))
  expect_equal(pts(sc, "QID1"), 6)
  expect_equal(pts(sc, "QID4"), 3)
})




test_that("an override beats a declared task on the same question", {
  out <- burden_report(ct_qsf(), quiet = TRUE, choice_tasks = ct(),
                       overrides = c(QID1 = 9))
  expect_equal(pts(out$items, "QID1"), 9)
  expect_equal(out$items$score_basis[out$items$question_id == "QID1"], "user override")
})

test_that("burden_report(responses =) applies declared tasks and overrides to respondents", {
  med <- function(rb) stats::median(rb$points[rb$outcome == "complete"])
  base <- respondent_burden(ct_qsf(), ct_responses())
  with_ct <- respondent_burden(ct_qsf(), ct_responses(), choice_tasks = ct())
  with_ov <- respondent_burden(ct_qsf(), ct_responses(), overrides = c(QID2 = 9))
  expect_gt(med(with_ct), med(base))

  r_ct <- burden_report(ct_qsf(), responses = ct_responses(), quiet = TRUE,
                        profile = FALSE, certainty = FALSE, choice_tasks = ct())
  expect_equal(r_ct$respondents$points[r_ct$respondents$statistic == "median"],
               med(with_ct))
  r_ov <- burden_report(ct_qsf(), responses = ct_responses(), quiet = TRUE,
                        profile = FALSE, certainty = FALSE, overrides = c(QID2 = 9))
  expect_equal(r_ov$respondents$points[r_ov$respondents$statistic == "median"],
               med(with_ov))
})
