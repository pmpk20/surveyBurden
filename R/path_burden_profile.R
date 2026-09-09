#' Structural burden profile across a path's display-logic sub-states
#'
#' [path_burden()] returns a floor/ceiling band per flow path. This function goes
#' inside the band and enumerates it.
#'
#' This function returns the \strong{structural burden profile}: every burden
#' value the path's display logic can produce, each counted once. It is not a
#' probability distribution. The quantiles below are unweighted order statistics
#' over the enumerated sub-states, not percentiles of a respondent population.
#' A real population average needs observed route frequencies; see
#' [respondent_burden()] for that.
#'
#' Each display-logic trigger is a *gate*: a single-choice question contributes
#' its referenced choices as mutually exclusive states; a multi-select or
#' embedded field contributes binary states; a Loop & Merge block contributes
#' iteration counts `1..max`. Conditional questions are grouped into coupling
#' components (two questions couple if they share a gate, directly or through a
#' chain of shared gates). **Small components are enumerated exactly** -- every
#' joint combination of their gates' states, respecting single-choice mutual
#' exclusion and AND-across-gates conditions precisely. Components too large to
#' enumerate (many questions sharing one popular trigger, such as employment
#' status) fall back to a primary-gate approximation for just that component:
#' each question is scored against its first gate with the rest held
#' permissive. Components are independent of each other and their contributions
#' convolved into the profile for the path.
#'
#' Remaining approximations: different components are treated as independent
#' (the real coupling between, say, employment status and having a licence is
#' weak, but not checked); large components use the primary-gate approximation
#' above; loop iterations are scored at a flat per-iteration burden (within-loop
#' display logic ignored).
#'
#' @param qsf A `qsf_raw` object.
#' @param weights A [gfs_weights()] list.
#' @param max_paths Passed to [resolve_paths()].
#' @param engine Optional precomputed `burden_engine()` result for this `qsf`
#'   (internal reuse; `NULL` builds it here, leaving the public behaviour
#'   unchanged).
#'
#' @return A [tibble][tibble::tibble], one row per flow path:
#'   `path_id`, `terminates_early`, `n_gates`,
#'   `burden_min`, `burden_p25`, `burden_median`, `burden_p75`, `burden_max`
#'   (unweighted order statistics of the profile), and list column `profile`
#'   (`tibble(burden, weight)` -- `weight` is a count of sub-states, not a
#'   probability).
#'
#' @export
path_burden_profile <- function(qsf, weights = gfs_weights(), max_paths = 10000L,
                                engine = NULL) {
  e <- engine %||% burden_engine(qsf, weights = weights, max_paths = max_paths)

  rows <- lapply(seq_len(nrow(e$paths)), function(i) {
    cp <- e$components[[i]]
    prof <- assemble_path_distribution(cp)
    q <- weighted_quantile(prof$burden, prof$weight, c(0, .25, .5, .75, 1))
    tibble::tibble(
      path_id = e$paths$path_id[i],
      terminates_early = e$paths$terminates_early[i],
      n_gates = e$paths$n_gates[i],
      burden_min = q[1], burden_p25 = q[2], burden_median = q[3],
      burden_p75 = q[4], burden_max = q[5],
      profile = list(prof)
    )
  })
  do.call(rbind, rows)
}

#' Shared setup for the path-burden family: parse, score, resolve paths, and
#' compute per-path burden components (base / loops / display distribution).
#' Returns a list with `paths` and `components` (one `list(base, loops,
#' display_dist)` per path), plus `blocks`, `scored` and `weights`.
#' `paths`, `scored` and `blocks` may be passed in precomputed (internal reuse
#' by [burden_report()]); each defaults to `NULL` and is then computed here.
#' @noRd
burden_engine <- function(qsf, weights = gfs_weights(), max_paths = 10000L,
                          paths = NULL, scored = NULL, blocks = NULL) {
  if (is.null(paths))  paths  <- resolve_paths(qsf, max_paths = max_paths)
  if (is.null(scored)) scored <- score_burden(parse_qsf(qsf), weights = weights)
  if (is.null(blocks)) blocks <- resolve_live_blocks(qsf)

  gfs    <- stats::setNames(scored$gfs_points, scored$question_id)
  stype  <- stats::setNames(scored$std_type,  scored$question_id)
  qblock <- stats::setNames(scored$block_id,  scored$question_id)

  sq <- qsf_elements(qsf, "SQ")
  raw <- stats::setNames(sq, vapply(sq, function(p) p$QuestionID %||% NA_character_, character(1)))
  parsed <- list()
  for (qid in scored$question_id[scored$has_display_logic]) {
    dl <- raw[[qid]]$DisplayLogic
    if (!is.null(dl)) parsed[[qid]] <- parse_display_logic(dl)
  }

  loop_blocks <- stats::setNames(blocks$loop_max, blocks$block_id)
  loop_blocks <- loop_blocks[!is.na(loop_blocks)]

  memo <- new.env(parent = emptyenv())
  components <- lapply(seq_len(nrow(paths)), function(i) {
    one_path_components(
      q_always = paths$q_always[[i]], q_maybe = paths$q_maybe[[i]],
      block_ids = paths$block_ids[[i]],
      parsed = parsed, gfs = gfs, stype = stype,
      qblock = qblock, loop_blocks = loop_blocks, memo = memo
    )
  })

  list(paths = paths, components = components,
       blocks = blocks, scored = scored, weights = weights)
}

#' Convolve a path's components into a burden distribution (loops uniform 1..max).
#' @noRd
assemble_path_distribution <- function(cp) {
  d <- data.frame(burden = cp$base, weight = 1)
  for (lp in cp$loops) {
    d <- convolve_dist(d, data.frame(burden = lp$per_iter * seq_len(lp$n), weight = 1 / lp$n))
  }
  d <- convolve_dist(d, cp$display_dist)
  tibble::tibble(burden = d$burden, weight = d$weight)
}

#' Burden components for one flow path: base, loops, display-logic distribution.
#' @return list(base, loops = named list of list(per_iter, n), display_dist df)
#' @noRd
one_path_components <- function(q_always, q_maybe, block_ids,
                                parsed, gfs, stype, qblock, loop_blocks,
                                memo = new.env(parent = emptyenv())) {
  loop_bids <- intersect(block_ids, names(loop_blocks))
  loop_qids <- names(qblock)[qblock %in% loop_bids]

  q_always_main <- setdiff(q_always, loop_qids)
  q_maybe_main  <- setdiff(q_maybe,  loop_qids)
  base <- sum(gfs[q_always_main], na.rm = TRUE)

  loops <- list()
  for (bid in loop_bids) {
    lq <- intersect(names(qblock)[qblock == bid], c(q_always, q_maybe))
    loops[[bid]] <- list(per_iter = sum(gfs[lq], na.rm = TRUE), n = loop_blocks[[bid]])
  }

  display_dist <- data.frame(burden = 0, weight = 1)
  cond <- q_maybe_main[q_maybe_main %in% names(parsed)]
  if (length(cond) > 0) {
    for (grp in connected_components(cond, parsed)) {
      gvars <- unique(unlist(lapply(grp, function(q) parsed[[q]]$vars)))
      disp  <- intersect(q_always, unlist(lapply(grp, function(q) parsed[[q]]$displayed)))
      key <- paste0(paste(sort(gvars), collapse = ","), "|",
                    paste(sort(grp), collapse = ","), "|",
                    paste(sort(disp), collapse = ","))
      cc <- memo[[key]]
      if (is.null(cc)) {
        cc <- component_dist(grp, gvars, parsed, gfs, stype, q_always)
        memo[[key]] <- cc
      }
      display_dist <- convolve_dist(display_dist, cc)
    }
  }

  list(base = base, loops = loops, display_dist = display_dist)
}

#' Group conditional questions into independent coupling components: two
#' questions are in the same component if they share a gate variable, directly
#' or transitively (question A depends on gate G, question B also depends on
#' gate G -> A and B are coupled; if B is itself a gate for question C, C joins
#' the same component too).
#' @return A list of character vectors of question ids.
#' @noRd
connected_components <- function(cond, parsed) {
  parent <- new.env(parent = emptyenv())
  find <- function(k) {
    if (is.null(parent[[k]])) { parent[[k]] <- k; return(k) }
    while (!identical(parent[[k]], k)) k <- parent[[k]]
    k
  }
  union <- function(a, b) {
    ra <- find(a); rb <- find(b)
    if (!identical(ra, rb)) parent[[ra]] <- rb
  }
  for (q in cond) for (v in parsed[[q]]$vars) union(q, v)
  roots <- vapply(cond, find, character(1))
  unname(split(cond, roots))
}

#' Burden contribution distribution for one coupling component. Enumerates the
#' true joint state space when it's small enough to be tractable
#' (`exact_cap`); larger components (a handful of gates shared by dozens of
#' questions, common when many questions key off one popular trigger question
#' like employment status) fall back to the primary-gate approximation used
#' throughout -- assigning each question to its first gate and holding the
#' rest permissive -- restricted to just this component.
#' @return data.frame(burden, weight)
#' @noRd
component_dist <- function(grp, gvars, parsed, gfs, stype, q_always, exact_cap = EXACT_CAP) {
  states <- lapply(gvars, function(v) gate_states(v, grp, parsed, stype))
  names(states) <- gvars
  total <- prod(vapply(states, length, integer(1)))

  if (length(gvars) <= 1 || total <= exact_cap) {
    return(component_dist_exact(grp, gvars, states, parsed, gfs, q_always))
  }
  component_dist_fallback(grp, parsed, gfs, stype, q_always)
}

#' Exact joint enumeration of a component's gate states.
#' @noRd
component_dist_exact <- function(grp, gvars, states, parsed, gfs, q_always) {
  shown0 <- stats::setNames(rep(TRUE, length(q_always)), q_always)
  grid <- expand.grid(lapply(states, seq_along), KEEP.OUT.ATTRS = FALSE)
  n <- nrow(grid)

  burdens <- vapply(seq_len(n), function(r) {
    assign <- stats::setNames(
      lapply(seq_along(gvars), function(j) states[[j]][[grid[r, j]]]),
      gvars
    )
    b <- 0
    for (q in grp) {
      if (isTRUE(parsed[[q]]$predicate(assign, shown0))) b <- b + (gfs[[q]] %||% 0)
    }
    b
  }, numeric(1))

  d <- group_sum(round(burdens, 1), rep(1, n))
  d$weight <- d$weight / n
  d
}

#' Primary-gate approximation for a component too large to enumerate exactly.
#' @noRd
component_dist_fallback <- function(grp, parsed, gfs, stype, q_always) {
  owner <- vapply(grp, function(q) parsed[[q]]$vars[1], character(1))
  by_gate <- split(grp, owner)
  d <- data.frame(burden = 0, weight = 1)
  for (v in names(by_gate)) {
    dep <- sort(by_gate[[v]])
    d <- convolve_dist(d, gate_component(v, dep, parsed, gfs, stype, q_always))
  }
  d
}

#' Burden distribution for one flow path (loops uniform over 1..max).
#' @return tibble(burden, weight)
#' @noRd
one_path_distribution <- function(q_always, q_maybe, block_ids,
                                  parsed, gfs, stype, qblock, loop_blocks,
                                  memo = new.env(parent = emptyenv())) {
  cp <- one_path_components(q_always, q_maybe, block_ids,
                            parsed, gfs, stype, qblock, loop_blocks, memo)
  d <- data.frame(burden = cp$base, weight = 1)
  for (lp in cp$loops) {
    d <- convolve_dist(d, data.frame(burden = lp$per_iter * seq_len(lp$n), weight = 1 / lp$n))
  }
  d <- convolve_dist(d, cp$display_dist)
  tibble::tibble(burden = d$burden, weight = d$weight)
}

#' Burden contribution distribution from one gate and the questions it owns.
#' @return data.frame(burden, weight)
#' @noRd
gate_component <- function(v, deps, parsed, gfs, stype, q_always) {
  states <- gate_states(v, deps, parsed, stype)
  other_vars <- setdiff(unique(unlist(lapply(deps, function(q) parsed[[q]]$vars))), v)
  shown0 <- stats::setNames(rep(TRUE, length(q_always)), q_always)

  burdens <- vapply(states, function(s) {
    assign <- stats::setNames(list(s), v)
    b <- 0
    for (q in deps) {
      if (isTRUE(parsed[[q]]$predicate(assign, shown0, permissive = other_vars))) {
        b <- b + (gfs[[q]] %||% 0)
      }
    }
    b
  }, numeric(1))

  d <- group_sum(round(burdens, 1), rep(1, length(burdens)))
  d$weight <- d$weight / sum(d$weight)   # each gate state weighted equally
  d
}

#' Fast group-sum of weights by (rounded) burden value.
#' @noRd
group_sum <- function(burden, weight) {
  k <- as.integer(round(burden * 10))
  u <- sort.int(unique(k))
  idx <- match(k, u)
  w <- as.numeric(rowsum(weight, idx))   # reorder = TRUE: rows in idx (=u) order
  data.frame(burden = u / 10, weight = w)
}

#' Possible states of a gate variable.
#' @noRd
gate_states <- function(v, deps, parsed, stype) {
  if (startsWith(v, "@")) return(list(TRUE, FALSE))
  refs <- unique(unlist(lapply(deps, function(q) lits_refs(parsed[[q]], v))))
  if (length(refs) == 0) return(list(TRUE, FALSE))
  if (identical(stype[[v]] %||% "", "single_choice")) {
    c(lapply(refs, identity), list(character(0)))
  } else {
    if (length(refs) > 6) refs <- refs[seq_len(6)]
    subs <- unlist(lapply(0:length(refs), function(k) utils::combn(refs, k, simplify = FALSE)),
                   recursive = FALSE)
    subs
  }
}

#' The choice-locator tails a parsed condition references for a given QID.
#' @noRd
lits_refs <- function(p, qid) p$refs[[qid]] %||% character(0)

#' Weighted quantiles (step function, lower value).
#' @noRd
weighted_quantile <- function(x, w, probs) {
  o <- order(x); x <- x[o]; w <- w[o]
  cw <- cumsum(w) / sum(w)
  vapply(probs, function(p) x[which(cw >= p - 1e-9)[1]], numeric(1))
}

#' Convolve two (burden, weight) distributions; bin to keep size bounded.
#' @noRd
convolve_dist <- function(a, b) {
  burden <- as.vector(outer(a$burden, b$burden, `+`))
  weight <- as.vector(outer(a$weight, b$weight, `*`))
  d <- group_sum(round(burden, 1), weight)
  if (nrow(d) > 3000) d <- group_sum(round(d$burden / 5) * 5, d$weight)
  d
}
