# Display logic inside Loop & Merge blocks: the iteration-position gate,
# gate classification, and the loop-aware structural profile.





# ---- loop-aware structural profile -------------------------------------------

test_that("shared gate holds one state across iterations", {
  # QIDh 1 pt; loop (max 2) QIDb 2 pts shown when QIDh = 1
  q <- lp_qsf(list(list(id = "BL_M", qs = list(fg_mc("QIDh", 2))),
                   list(id = "BL_L", loop = 2, qs = list(fg_mc("QIDb", 3, fg_logic(lp_sel("QIDh", 1)))))))
  lp_expect(lp_dist(q), c(`1` = .5, `3` = .25, `5` = .25))
})

test_that("iteration gate varies independently across iterations", {
  # loop (max 2): QIDa 1 pt always; QIDb 2 pts when this iteration's QIDa = 1
  q <- lp_qsf(list(list(id = "BL_L", loop = 2, qs = list(
    fg_mc("QIDa", 2), fg_mc("QIDb", 3, fg_logic(lp_sel("QIDa", 1)))))))
  lp_expect(lp_dist(q), c(`1` = .25, `3` = .25, `2` = .125, `4` = .25, `6` = .125))
})

test_that("n = 1 vs n = 2 totals follow loop_weights", {
  q <- lp_qsf(list(list(id = "BL_L", loop = 2, qs = list(
    fg_mc("QIDa", 2), fg_mc("QIDb", 3, fg_logic(lp_sel("QIDa", 1)))))))
  lp_expect(lp_dist(q, loop_weights = list(BL_L = c(1, 0))), c(`1` = .5, `3` = .5))
  lp_expect(lp_dist(q, loop_weights = list(BL_L = c(0, 1))), c(`2` = .25, `4` = .5, `6` = .25))
  lp_expect(lp_dist(q, loop_weights = list(BL_L = function(state) c(0, 3))),
            c(`2` = .25, `4` = .5, `6` = .25))
})


test_that("shared gate couples loop and non-loop questions", {
  # QIDh 1 pt; QIDm 3 pts and loop QIDb 2 pts both shown when QIDh = 1
  q <- lp_qsf(list(list(id = "BL_M", qs = list(fg_mc("QIDh", 2), fg_mc("QIDm", 7, fg_logic(lp_sel("QIDh", 1))))),
                   list(id = "BL_L", loop = 1, qs = list(fg_mc("QIDb", 3, fg_logic(lp_sel("QIDh", 1)))))))
  lp_expect(lp_dist(q), c(`1` = .5, `6` = .5))
})


test_that("nested gate: B never shown when A is hidden", {
  # X 1 pt always; A 1 pt when X = 1; B 3 pts when A = 1
  q <- lp_qsf(list(list(id = "BL_M", qs = list(
    fg_mc("QIDx", 2), fg_mc("QIDa", 2, fg_logic(lp_sel("QIDx", 1))),
    fg_mc("QIDb", 7, fg_logic(lp_sel("QIDa", 1)))))))
  lp_expect(lp_dist(q, respect_force_response = FALSE), c(`1` = .5, `2` = .25, `5` = .25))
})

test_that("forced-response trigger has no unanswered state", {
  # T (2 choices, 1 pt): Q2 (2 pts) when T = 1, Q3 (3 pts) when T = 2
  mk <- function(t) lp_qsf(list(list(id = "BL_M", qs = list(
    t, fg_mc("QID2", 3, fg_logic(lp_sel("QIDt", 1))), fg_mc("QID3", 7, fg_logic(lp_sel("QIDt", 2)))))))
  forced <- mk(lp_forced(fg_mc("QIDt", 2)))
  lp_expect(lp_dist(forced), c(`3` = .5, `4` = .5))
  lp_expect(lp_dist(forced, respect_force_response = FALSE), c(`1` = 1/3, `3` = 1/3, `4` = 1/3))
  lp_expect(lp_dist(mk(lp_forced(fg_mc("QIDt", 2), "RequestResponse"))),
            c(`1` = 1/3, `3` = 1/3, `4` = 1/3))
  # three choices, two referenced: "none" (answered choice 3) stays
  three <- mk(lp_forced(fg_mc("QIDt", 3)))
  lp_expect(lp_dist(three), c(`2` = 1/3, `4` = 1/3, `5` = 1/3))
})




# ---- final-review fixes ------------------------------------------------------

lp_notsel <- function(qid, choice) { x <- lp_sel(qid, choice); x$Operator <- "NotSelected"; x }

test_that("C1: function loop weights on a loop without display logic", {
  q <- lp_qsf(list(list(id = "BL_L", loop = 2, qs = list(fg_mc("QIDa", 2)))))
  lp_expect(lp_dist(q, loop_weights = list(BL_L = function(s) c(1, 3))), c(`1` = .25, `2` = .75))
})

test_that("I1: hidden triggers settle in dependency order, whatever the catalogue order", {
  # X always; B if X = 1; A if B NotSelected 1; C (3 pts) if A = 1. C listed before A.
  q <- lp_qsf(list(list(id = "BL_M", qs = list(
    fg_mc("QIDx", 2), fg_mc("QIDc", 7, fg_logic(lp_sel("QIDa", 1))),
    fg_mc("QIDb", 2, fg_logic(lp_sel("QIDx", 1))), fg_mc("QIDa", 2, fg_logic(lp_notsel("QIDb", 1)))))))
  lp_expect(lp_dist(q, respect_force_response = FALSE),
            c(`2` = .5, `3` = .125, `5` = .25, `6` = .125))
})

test_that("I2: many independent iteration triggers stay exact (no silent permissive cap)", {
  # loop (max 2): 14 independent pairs, trigger (1 pt) -> dependant (2 pts) on choice 1
  qs <- unlist(lapply(seq_len(14), function(i) {
    t <- sprintf("QIDt%02d", i)
    list(fg_mc(t, 2), fg_mc(sprintf("QIDd%02d", i), 3, fg_logic(lp_sel(t, 1))))
  }), recursive = FALSE)
  q <- lp_qsf(list(list(id = "BL_L", loop = 2, qs = qs)))
  d <- lp_dist(q)
  mean_b <- sum(as.numeric(names(d)) * d)
  # per iteration: 14 + 14 * 2 * 0.5 = 28 points; uniform n in {1, 2} -> 1.5 iterations
  expect_equal(mean_b, 42, tolerance = 1e-9)
})

test_that("M2: a loop trigger the route never shows does not show its dependants", {
  # In the loop, QIDa needs QIDzz (in a block outside the flow), so it is never
  # shown; QIDb (2 pts) shows if this iteration's QIDa = 1 OR QIDh = 1 (QIDh 1 pt)
  q <- lp_qsf(list(list(id = "BL_M", qs = list(fg_mc("QIDh", 2))),
                   list(id = "BL_L", loop = 1, qs = list(
                     fg_mc("QIDa", 2, fg_logic(lp_sel("QIDzz", 1))),
                     fg_mc("QIDb", 3, fg_logic(lp_sel("QIDa", 1), lp_sel("QIDh", 1, conj = "Or")))))))
  q <- lp_add_unflowed_block(q, "BL_S", fg_mc("QIDzz", 2))
  lp_expect(lp_dist(q), c(`1` = .5, `3` = .5))
})

