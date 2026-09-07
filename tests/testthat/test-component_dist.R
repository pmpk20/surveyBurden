# --- synthetic DisplayLogic builders (same shape as test-parse_display_logic.R) ---
.lit_q <- function(qid, choice, op = "Selected", conj = NULL) {
  loc <- sprintf("q://%s/SelectableChoice/%s", qid, choice)
  x <- list(LogicType = "Question", QuestionID = qid, Operator = op,
            LeftOperand = loc, ChoiceLocator = loc, Type = "Expression")
  if (!is.null(conj)) x$Conjuction <- conj
  x
}
.grp <- function(...) {
  g <- list(...); names(g) <- as.character(seq_along(g) - 1L); g$Type <- "If"; g
}
.dl_of <- function(...) {
  d <- list(...); names(d) <- as.character(seq_along(d) - 1L)
  d$Type <- "BooleanExpression"; d
}
.and_condition <- function(qidA, choiceA, qidB, choiceB) {
  .dl_of(.grp(.lit_q(qidA, choiceA), .lit_q(qidB, choiceB, conj = "And")))
}

test_that("connected_components groups questions that share a gate", {
  parsed <- list(
    Q1 = parse_display_logic(.dl_of(.grp(.lit_q("GATE1", "1")))),
    Q2 = parse_display_logic(.dl_of(.grp(.lit_q("GATE1", "2")))),
    Q3 = parse_display_logic(.dl_of(.grp(.lit_q("GATE2", "1"))))
  )
  comps <- connected_components(c("Q1", "Q2", "Q3"), parsed)
  expect_equal(length(comps), 2L)
  sizes <- sort(lengths(comps))
  expect_equal(sizes, c(1L, 2L))
})

test_that("an AND-across-two-gates condition is scored exactly, not with a permissive gate", {
  # Q1 is shown only when GATE1 choice 1 is selected AND GATE2 choice 1 is
  # selected -- true for exactly one joint state, not "true whenever the
  # primary gate says so".
  dl <- .and_condition("GATE1", "1", "GATE2", "1")
  parsed <- list(Q1 = parse_display_logic(dl))
  gfs <- c(Q1 = 10)
  stype <- c(GATE1 = "single_choice", GATE2 = "single_choice")

  gvars <- parsed$Q1$vars
  expect_setequal(gvars, c("GATE1", "GATE2"))

  d <- component_dist(grp = "Q1", gvars = gvars, parsed = parsed,
                      gfs = gfs, stype = stype, q_always = character(0))

  # GATE1 has 1 referenced choice -> 2 states (chosen / not); same for GATE2.
  # Only the (chosen, chosen) joint state shows Q1 -> burden 10 with weight 1
  # out of 4 equally-likely joint states; burden 0 the other 3.
  expect_setequal(d$burden, c(0, 10))
  hit <- d[d$burden == 10, ]
  miss <- d[d$burden == 0, ]
  expect_equal(hit$weight, miss$weight / 3, tolerance = 1e-8)
})

test_that("component_dist falls back to the primary-gate approximation above exact_cap", {
  dl <- .and_condition("GATE1", "1", "GATE2", "1")
  parsed <- list(Q1 = parse_display_logic(dl))
  gfs <- c(Q1 = 10)
  stype <- c(GATE1 = "single_choice", GATE2 = "single_choice")
  gvars <- parsed$Q1$vars

  exact    <- component_dist("Q1", gvars, parsed, gfs, stype, character(0), exact_cap = 5000L)
  fallback <- component_dist("Q1", gvars, parsed, gfs, stype, character(0), exact_cap = 0L)

  # fallback (primary gate GATE1, GATE2 held permissive) shows Q1 whenever
  # GATE1 hits, i.e. in half its states -- heavier / different from exact
  expect_false(isTRUE(all.equal(sort(exact$weight), sort(fallback$weight))))
})

test_that("path_burden_profile's minimum is at least the naive floor", {
  qsf <- read_qsf(demo_qsf())
  band <- path_burden(qsf)
  prof <- path_burden_profile(qsf)
  m <- merge(band[, c("path_id", "gfs_floor")], prof[, c("path_id", "burden_min")], by = "path_id")
  expect_true(all(m$burden_min >= m$gfs_floor - 1e-6))
})
