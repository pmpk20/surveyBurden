# path_burden_traversals(): burden by block for each weighted traversal.

pbt <- function(...) suppressMessages(suppressWarnings(path_burden_traversals(...)))
tot <- function(x) {
  t <- stats::aggregate(cbind(points, response_items, pages) ~ traversal_id + path_id + weight,
                        data = as.data.frame(x), FUN = sum)
  t[order(t$traversal_id), ]
}
# Loop (max 2): QIDa 1 pt always; QIDb 2 pts when this iteration's QIDa = 1.
iter_fx <- function() lp_qsf(list(list(id = "BL_L", loop = 2, qs = list(
  fg_mc("QIDa", 2), fg_mc("QIDb", 3, fg_logic(lp_sel("QIDa", 1)))))))
# Loop A (3 iterations, forced QIDa, 2 choices), then QIDz (3 pts) shown when
# the derived field cnt (number of iterations answering 1) is at least 2.
rule_fx <- function() lp_qsf(list(
  list(id = "BL_A", loop = 3, qs = list(lp_forced(fg_mc("QIDa", 2)))),
  list(id = "BL_Z", qs = list(fg_mc("QIDz", 7, fg_logic(fg_emb("cnt", "GreaterThanOrEqual", "2")))))))
cnt_rule <- function(na_if_zero = FALSE) list(`@cnt` = list(inputs = "QIDa", fun = function(s) {
  k <- sum(vapply(1:3, function(j) identical(s[[paste0("QIDa#", j)]], "1"), logical(1)))
  if (na_if_zero && k == 0) NA else k
}))

test_that("block burdens sum to the traversal total and weights sum to 1", {
  x <- pbt(read_qsf(demo_qsf()), method = "exact")
  t <- tot(x)
  expect_equal(sum(t$weight), 1)
  expect_true(all(c("traversal_id", "path_id", "weight", "block_id", "flow_order", "iterations",
                    "points", "items", "response_items", "pages") %in% names(x)))
  expect_identical(attr(x, "method")$method, rep("exact", length(unique(x$path_id))))
})

test_that("exact traversal quantiles equal the profile", {
  probs <- c(0, .25, .5, .75, 1)
  for (q in list(iter_fx(), read_qsf(system.file("extdata", "demo_display_logic.qsf", package = "surveyBurden")),
                 read_qsf(demo_qsf()))) {
    t <- tot(pbt(q, method = "exact", respect_force_response = FALSE))
    r <- suppressMessages(burden_report(q, quiet = TRUE, respect_force_response = FALSE))
    expect_equal(weighted_quantile(t$points, t$weight, probs), r$burden$points)
  }
})

test_that("sampling is reproducible and close to exact", {
  a <- pbt(iter_fx(), method = "sample", n_draws = 20000, seed = 1)
  b <- pbt(iter_fx(), method = "sample", n_draws = 20000, seed = 1)
  expect_identical(a, b)
  ta <- tot(a); te <- tot(pbt(iter_fx(), method = "exact"))
  expect_lte(abs(weighted_quantile(ta$points, ta$weight, .5) -
                   weighted_quantile(te$points, te$weight, .5)), 1)
  expect_identical(attr(a, "method")$method, "sample")
})

test_that("field rule derives a field from iteration answers and gates a non-loop question", {
  x <- pbt(rule_fx(), method = "exact", loop_weights = list(BL_A = c(0, 0, 1)),
           field_rules = cnt_rule())
  t <- tot(x)
  # derived, never enumerated: 2^3 answer patterns only
  expect_equal(nrow(t), 8L)
  z <- x[x$block_id == "BL_Z", ]
  expect_equal(sum(z$weight[z$points > 0]), 0.5)
})

test_that("rejected share and method are reported", {
  x <- pbt(rule_fx(), method = "exact", loop_weights = list(BL_A = c(0, 0, 1)),
           field_rules = cnt_rule(na_if_zero = TRUE))
  expect_equal(attr(x, "rejected")$rejected_share, 1 / 8)
  expect_equal(sum(tot(x)$weight), 1)
  expect_identical(attr(x, "method")$method, "exact")
})

test_that("a loop-count rule sets iterations and forces sampling", {
  r <- list(`@@n:BL_L` = function(s) 2)
  x <- pbt(iter_fx(), method = "auto", n_draws = 200, field_rules = r)
  expect_true(all(x$iterations[x$block_id == "BL_L"] == 2))
  expect_identical(attr(x, "method")$method, "sample")
  expect_error(pbt(iter_fx(), method = "exact", field_rules = r), "sample")
})

test_that("a rule rejecting everything errors, naming the path", {
  r <- list(`@cnt` = list(inputs = "QIDa", fun = function(s) NA))
  for (m in c("exact", "sample")) {
    expect_error(pbt(rule_fx(), method = m, n_draws = 50, field_rules = r), "path 1")
  }
})

test_that("method exact refuses large spaces; auto falls back to sampling", {
  expect_error(pbt(iter_fx(), method = "exact", max_traversals = 3), "sample")
  x <- pbt(iter_fx(), method = "auto", max_traversals = 3, n_draws = 100)
  expect_identical(attr(x, "method")$method, "sample")
})

test_that("nested gate in traversals: B only when A is shown and A = 1", {
  q <- lp_qsf(list(
    list(id = "BL_X", qs = list(fg_mc("QIDx", 2))),
    list(id = "BL_A", qs = list(lp_forced(fg_mc("QIDa", 2, fg_logic(lp_sel("QIDx", 1)))))),
    list(id = "BL_B", qs = list(fg_mc("QIDb", 7, fg_logic(lp_sel("QIDa", 1))))),
    list(id = "BL_C", qs = list(fg_mc("QIDc", 7, fg_logic(lp_sel("QIDa", 2)))))))
  x <- as.data.frame(pbt(q, method = "exact"))
  w <- reshape(x[, c("traversal_id", "weight", "block_id", "points")], idvar = c("traversal_id", "weight"),
               timevar = "block_id", direction = "wide")
  expect_equal(nrow(w), 3L)
  expect_true(all(w$points.BL_A[w$points.BL_B > 0] > 0))
  expect_equal(sum(w$weight[w$points.BL_A > 0]), 0.5)
  expect_equal(sum(w$weight[w$points.BL_B > 0]), 0.25)
  expect_equal(sum(w$weight[w$points.BL_C > 0]), 0.25)
})

test_that("sampling is stratified by route", {
  q <- read_qsf(system.file("extdata", "demo_large_branching.qsf", package = "surveyBurden"))
  x <- pbt(q, method = "sample", n_draws = 500, seed = 2)
  t <- tot(x)
  n_routes <- length(unique(t$path_id))
  expect_true(all(table(t$path_id) == 500))
  expect_equal(as.numeric(tapply(t$weight, t$path_id, sum)), rep(1 / n_routes, n_routes))
})

test_that("summary output equals long output on the same seed", {
  q <- read_qsf(demo_qsf())
  probs <- c(0, .1, .5, .9, 1)
  long <- pbt(q, method = "sample", n_draws = 3000, seed = 3)
  s    <- pbt(q, method = "sample", n_draws = 3000, seed = 3, output = "summary", probs = probs)
  t <- tot(long)
  expect_equal(s$totals$points, weighted_quantile(t$points, t$weight, probs))
  expect_equal(s$totals$response_items, weighted_quantile(t$response_items, t$weight, probs))
  expect_equal(s$totals$pages, weighted_quantile(t$pages, t$weight, probs))
  # cumulative points after a mid-survey block: blocks a route skips add zero
  lx <- as.data.frame(long)
  k <- sort(unique(lx$flow_order))[ceiling(length(unique(lx$flow_order)) / 2)]
  cum <- stats::aggregate(points ~ traversal_id + weight, data = transform(lx, points = points * (flow_order <= k)), FUN = sum)
  expect_equal(s$cumulative$points[s$cumulative$flow_order == k],
               weighted_quantile(cum$points, cum$weight, probs))
  w <- pbt(q, method = "sample", n_draws = 200, seed = 3, output = "wide")
  expect_equal(nrow(w), length(unique(w$traversal_id)))
})

test_that("traversal_stability reports per-seed quantiles", {
  st <- suppressMessages(traversal_stability(iter_fx(), seeds = 1:3, n_draws = 2000))
  expect_equal(nrow(st$per_seed), 3L)
  expect_true(all(c("seed", "p10", "median", "p90") %in% names(st$per_seed)))
  expect_true(all(c("median", "p10", "p90") %in% names(st$range)))
})

# ---- final-review fixes ------------------------------------------------------

test_that("C1: traversals of surveys and routes without display logic", {
  q <- read_qsf(system.file("extdata", "demo_simple_linear.qsf", package = "surveyBurden"))
  x <- pbt(q, method = "exact")
  expect_equal(sum(tot(x)$weight), 1)
  ql <- lp_qsf(list(list(id = "BL_L", loop = 2, qs = list(fg_mc("QIDa", 2)))))
  expect_equal(sort(unique(tot(pbt(ql, method = "exact"))$points)), c(1, 2))
})

test_that("I4: function loop weights use the shared state in traversals too", {
  # digit ids, as in real QSFs: choice tails are then bare ids ("1")
  q <- lp_qsf(list(list(id = "BL_M", qs = list(fg_mc("QID901", 2))),
                   list(id = "BL_L", loop = 2, qs = list(fg_mc("QID902", 3, fg_logic(lp_sel("QID901", 1)))))))
  w <- list(BL_L = function(s) if (identical(s[["QID901"]], "1")) c(0, 1) else c(1, 0))
  t <- tot(pbt(q, method = "exact", loop_weights = w))
  prof <- lp_dist(q, loop_weights = w)
  expect_equal(weighted_quantile(t$points, t$weight, c(0, .5, 1)),
               weighted_quantile(as.numeric(names(prof)), unname(prof), c(0, .5, 1)))
  expect_equal(sort(unique(t$points)), c(1, 5))
})

test_that("I6: a rule reading an undeclared question errors, naming the rule", {
  r <- list(`@cnt` = list(inputs = "QIDa", fun = function(s) if (identical(s[["QID9"]], "1")) 1 else 0))
  expect_error(pbt(rule_fx(), method = "exact", field_rules = r), "@cnt")
})

test_that("M7: a rule's final value decides rejection, not an early evaluation", {
  # QIDz (before the loop) reads @cnt; the rule returns NA while QIDa is unanswered
  q <- lp_qsf(list(
    list(id = "BL_Z", qs = list(fg_mc("QIDz", 7, fg_logic(fg_emb("cnt", "GreaterThanOrEqual", "2"))))),
    list(id = "BL_A", loop = 1, qs = list(lp_forced(fg_mc("QIDa", 2))))))
  r <- list(`@cnt` = list(inputs = "QIDa", fun = function(s) {
    a <- s[["QIDa#1"]]; if (!length(a)) NA else as.integer(identical(a, "1")) }))
  x <- pbt(q, method = "exact", field_rules = r)
  expect_equal(attr(x, "rejected")$rejected_share, 0)
})

test_that("I5: rule evaluation keys on declared inputs only", {
  # an unrelated trigger (QIDh -> QIDk) must not leak into the rule's state
  q <- lp_qsf(list(
    list(id = "BL_H", qs = list(fg_mc("QIDh", 2), fg_mc("QIDk", 3, fg_logic(lp_sel("QIDh", 1))))),
    list(id = "BL_A", loop = 3, qs = list(lp_forced(fg_mc("QIDa", 2)))),
    list(id = "BL_Z", qs = list(fg_mc("QIDz", 7, fg_logic(fg_emb("cnt", "GreaterThanOrEqual", "2")))))))
  ok <- FALSE
  r <- list(`@cnt` = list(inputs = "QIDa", fun = function(s) {
    ok <<- all(names(s) %in% c("QIDa", paste0("QIDa#", 1:3)) | startsWith(names(s), "@@n:"))
    sum(vapply(1:3, function(j) identical(s[[paste0("QIDa#", j)]], "1"), logical(1)))
  }))
  pbt(q, method = "exact", loop_weights = list(BL_A = c(0, 0, 1)), field_rules = r)
  expect_true(ok)
})

test_that("a vectorised rule gives the same traversals as the per-row rule", {
  vec <- list(`@cnt` = list(inputs = "QIDa", vectorised = TRUE, fun = function(s) {
    # s: named list of whole columns; "" = unanswered, choice ids otherwise
    (s[["QIDa#1"]] == "1") + (s[["QIDa#2"]] == "1") + (s[["QIDa#3"]] == "1")
  }))
  a <- pbt(rule_fx(), method = "exact", loop_weights = list(BL_A = c(0, 0, 1)), field_rules = cnt_rule())
  b <- pbt(rule_fx(), method = "exact", loop_weights = list(BL_A = c(0, 0, 1)), field_rules = vec)
  expect_equal(as.data.frame(a), as.data.frame(b))
  sa <- pbt(rule_fx(), method = "sample", n_draws = 2000, seed = 4, field_rules = cnt_rule())
  sb <- pbt(rule_fx(), method = "sample", n_draws = 2000, seed = 4, field_rules = vec)
  expect_equal(as.data.frame(sa), as.data.frame(sb))
})

test_that("a vectorised rule must return one value per row", {
  bad <- list(`@cnt` = list(inputs = "QIDa", vectorised = TRUE, fun = function(s) 1:2))
  expect_error(pbt(rule_fx(), method = "exact", field_rules = bad), "@cnt")
})

# ---- deferred minors (M3-M6, M8, M9) -----------------------------------------

test_that("M3: a loop-count rule and loop_weights for the same loop warn", {
  expect_warning(path_burden_traversals(iter_fx(), method = "sample", n_draws = 50,
                                        loop_weights = list(BL_L = c(1, 1)),
                                        field_rules = list(`@@n:BL_L` = function(s) 2)),
                 "BL_L")
})

test_that("M4: a loop-count rule naming a non-loop block errors", {
  expect_error(pbt(iter_fx(), method = "sample", n_draws = 50,
                   field_rules = list(`@@n:BL_nope` = function(s) 1)), "BL_nope")
})

test_that("M5: a loop-count rule forces sampling only on routes with that loop", {
  # two routes: grp = 1 runs the loop BL_L, otherwise it is skipped
  q <- lp_qsf(list(list(id = "BL_M", qs = list(fg_mc("QIDx", 2))),
                   list(id = "BL_L", loop = 2, qs = list(fg_mc("QIDa", 2)))))
  q$SurveyElements <- lapply(q$SurveyElements, function(e) {
    if (identical(e$Element, "FL")) e$Payload$Flow <- list(
      list(Type = "EmbeddedData", FlowID = "FL_ed", EmbeddedData = list(list(
        Description = "grp", Type = "Recipient", Field = "grp", VariableType = "String"))),
      list(Type = "Standard", ID = "BL_M", FlowID = "FL_1"),
      list(Type = "Branch", FlowID = "FL_b", Description = "grp",
           BranchLogic = fg_logic(fg_emb("grp", "EqualTo", "1")),
           Flow = list(list(Type = "Standard", ID = "BL_L", FlowID = "FL_2"))))
    e
  })
  r <- list(`@@n:BL_L` = function(s) 1)
  m <- attr(pbt(q, method = "auto", n_draws = 20, field_rules = r), "method")
  expect_equal(nrow(m), 2L)
  expect_setequal(m$method, c("sample", "exact"))
})

test_that("M6: forward references are flagged", {
  # QIDb (first) is shown when QIDa (later in the flow) = 1
  q <- lp_qsf(list(list(id = "BL_M", qs = list(
    fg_mc("QIDb", 3, fg_logic(lp_sel("QIDa", 1))), fg_mc("QIDa", 2)))))
  u <- attr(pbt(q, method = "exact"), "unresolved")
  expect_true(any(u$question_id == "QIDb" & u$reason == "forward reference"))
})

test_that("M8: summary output is reduced per chunk and equals the long output", {
  q <- read_qsf(demo_qsf())
  probs <- c(.1, .5, .9)
  long <- pbt(q, method = "sample", n_draws = 2500, seed = 9, chunk = 700)
  s <- pbt(q, method = "sample", n_draws = 2500, seed = 9, chunk = 700, output = "summary", probs = probs)
  t <- tot(long)
  expect_equal(s$totals$points, weighted_quantile(t$points, t$weight, probs))
  expect_equal(s$totals$pages, weighted_quantile(t$pages, t$weight, probs))
})

test_that("M9: exact traversals equal the profile on the shared-gate and position fixtures", {
  probs <- c(0, .25, .5, .75, 1)
  qs <- list(
    lp_qsf(list(list(id = "BL_M", qs = list(fg_mc("QIDh", 2))),
                list(id = "BL_L", loop = 2, qs = list(fg_mc("QIDb", 3, fg_logic(lp_sel("QIDh", 1))))))),
    lp_qsf(list(list(id = "BL_L", loop = 3, qs = list(fg_mc("QIDp", 3, lp_pos_logic("BL_L", 1)), fg_mc("QIDq", 2))))))
  for (q in qs) {
    t <- tot(pbt(q, method = "exact", respect_force_response = FALSE))
    r <- suppressMessages(burden_report(q, quiet = TRUE, respect_force_response = FALSE))
    expect_equal(weighted_quantile(t$points, t$weight, probs), r$burden$points)
  }
})

test_that("M9: a loop block with no readable maximum is scored once, in both engines", {
  q <- lp_qsf(list(list(id = "BL_L", loop = 2, qs = list(fg_mc("QIDa", 2)))))
  q$SurveyElements <- lapply(q$SurveyElements, function(e) {
    if (identical(e$Element, "BL")) e$Payload[["0"]]$Options$LoopingOptions <- list()
    e
  })
  expect_true(is.na(resolve_live_blocks(q)$loop_max))
  lp_expect(lp_dist(q), c(`1` = 1))
  expect_equal(unique(tot(pbt(q, method = "exact"))$points), 1)
})
