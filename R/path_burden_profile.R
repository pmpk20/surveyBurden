#' Structural burden profile across a path's display-logic sub-states
#'
#' [path_burden()] returns a floor/ceiling band per flow path. This function goes
#' inside the band and enumerates it.
#'
#' This function returns the \strong{structural burden profile}: every burden
#' value the path's modelled display-logic states can produce, with a weight.
#' Each joint state of a component's gates (and each loop iteration count
#' `1..max`) gets equal weight, a burden value produced by several states
#' carries their combined weight, and each path's weights sum to 1. The
#' quantiles are weighted by these model weights. They are not observed
#' respondent frequencies, so they are not percentiles of a respondent
#' population; for that, use response data with [respondent_burden()].
#' [burden_report()] pools the complete paths' profiles, so each complete path
#' carries equal total weight there.
#'
#' Each display-logic trigger is a *gate*: a single-choice question contributes
#' its referenced choices as mutually exclusive states; a multi-select
#' contributes the subsets of its referenced choices; a stored (embedded data)
#' field contributes one state per distinguishable value class of the
#' comparisons made on it (each referenced value, the ranges between
#' thresholds, any other value, empty), so conditions on different values of
#' one field are mutually exclusive; a comparison the package cannot evaluate
#' (such as `Contains`) is a free true/false gate; a Loop & Merge block
#' contributes iteration counts `1..max`. Conditional questions are grouped into coupling
#' components (two questions couple if they share a gate, directly or through a
#' chain of shared gates). A component with at most `max_condition_states` joint gate-states is
#' **enumerated exactly** -- every joint combination of its gates' states,
#' respecting single-choice mutual exclusion and AND-across-gates conditions
#' precisely. A component above that (many questions sharing one popular
#' trigger, such as employment status) falls back to a primary-gate
#' approximation for just that component: each question is scored against its
#' first gate with the rest held permissive. Components are independent of each
#' other and their contributions convolved into the profile for the path.
#'
#' Loop & Merge blocks: display logic inside a loop is evaluated. A
#' trigger in the same loop block takes a fresh, equally weighted state in
#' each iteration (iterations are independent); a trigger outside the block
#' (another question or a stored field) keeps one state for every iteration
#' and is shared with non-loop questions that use it; a `LoopAndMerge`
#' "Loop k ... Current Loop" condition is evaluated from the iteration index.
#' Iteration counts `1..max` are weighted by `loop_weights` (equal by
#' default). A trigger question whose own condition fails is treated as
#' unanswered, so a question never appears because of an answer to a
#' question that was not shown. A trigger in a different loop block is
#' treated as shared and reported by the engine as unresolved.
#'
#' Remaining approximations: different components are treated as independent
#' (the real coupling between, say, employment status and having a licence is
#' weak, but not checked); components above the chosen state limit use the
#' primary-gate approximation above. Once a path's
#' convolved profile exceeds 3000 distinct burden values it is re-binned to
#' multiples of 5 GfS points, so on a very heavy survey the reported quantiles
#' can move a few points from the fine-grained figure.
#'
#' @param qsf A `qsf_raw` object.
#' @param scheme A [gfs_scheme()] list.
#' @param max_condition_states Maximum joint condition-state combinations
#'   enumerated in full per connected display-logic component (default 10000).
#'   Must be a positive finite whole number. Larger components use the
#'   primary-gate approximation. This is separate from `max_paths` and does
#'   not remove other modelling assumptions. When precomputed results are
#'   supplied, use the same limit that generated those results.
#' @param max_paths Passed to [resolve_paths()].
#' @param engine Optional precomputed `burden_engine()` result for this `qsf`
#'   (internal reuse; `NULL` builds it here, leaving the public behaviour
#'   unchanged).
#' @param parsed_dl Optional precomputed map of parsed display-logic trees for
#'   this `qsf` (internal reuse by [burden_report()]; ignored when `engine` is
#'   supplied, computed as needed when `NULL`).
#' @param overrides Optional named numeric vector of GfS+ points that replace
#'   the computed score of the named questions, e.g. `c(QID51 = 10)`. See
#'   [burden_report()]. Ignored, with a warning, when `engine` is supplied.
#' @param loop_weights Optional named list of loop-count weights, keyed by
#'   Loop & Merge block id: a non-negative numeric vector with one weight per
#'   iteration count `1..max` (normalised internally), or a function of the
#'   component's shared-gate states returning such a vector. `NULL` (default)
#'   weights each count equally, e.g. `list(BL_x = c(1, 1, 1, 9))`.
#' @param respect_force_response If `TRUE` (default), a display-logic trigger
#'   that the route shows and whose response is forced
#'   (`ForceResponse = "ON"`) has no unanswered state, when its referenced
#'   choices cover all its choices. `FALSE` gives the 0.2.0 behaviour.
#' @param field_domains Optional named list giving the values an
#'   embedded-data field can hold, e.g. `list(SP_05 = 0:5)`. Passed to
#'   [resolve_flow()]. Ignored, with a warning, when `engine` is supplied.
#' @param choice_tasks Optional data frame declaring stated-choice tasks
#'   (`question_id`, `n_alternatives`, `n_attributes`), scored by the GfS
#'   stated-choice rule. See [burden_report()]. Ignored, with a warning, when
#'   `engine` is supplied.
#'
#' @return A [tibble][tibble::tibble], one row per flow path:
#'   `path_id`, `terminates_early`, `n_gates`,
#'   `burden_min`, `burden_p25`, `burden_median`, `burden_p75`, `burden_max`
#'   (unweighted order statistics of the profile), and list column `profile`
#'   (`tibble(burden, weight)` -- `weight` is a count of sub-states, not a
#'   probability).
#'
#' @examples
#' \donttest{
#' qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
#'                          package = "surveyBurden")
#' pbp <- path_burden_profile(read_qsf(qsf_path))
#' pbp[, c("path_id", "burden_min", "burden_median", "burden_max")]
#' }
#'
#' @export
path_burden_profile <- function(qsf, scheme = gfs_scheme(), max_paths = 10000L,
                                engine = NULL, parsed_dl = NULL,
                                max_condition_states = 10000L, overrides = NULL,
                                choice_tasks = NULL, field_domains = NULL,
                                loop_weights = NULL, respect_force_response = TRUE) {
  validate_condition_states(max_condition_states)
  if (!is.null(engine) && (!is.null(overrides) || !is.null(choice_tasks))) {
    cli::cli_warn(c(
      "{.arg overrides} and {.arg choice_tasks} are ignored because a precomputed {.arg engine} was supplied.",
      i = "Leave out {.arg engine}, or build it with the same scoring adjustments."
    ))
  }
  if (!is.null(engine) && !is.null(field_domains)) {
    cli::cli_warn(c(
      "{.arg field_domains} is ignored because a precomputed {.arg engine} was supplied.",
      i = "Leave out {.arg engine}, or build it with the same {.arg field_domains}."
    ))
  }
  e <- engine %||% burden_engine(qsf, scheme = scheme, max_paths = max_paths,
                                 parsed_dl = parsed_dl, overrides = overrides,
                                 choice_tasks = choice_tasks,
                                 max_condition_states = max_condition_states,
                                 field_domains = field_domains,
                                 loop_weights = loop_weights,
                                 respect_force_response = respect_force_response)

  # Fill plain vectors per path and build the tibble once: a tibble() per path
  # (then rbind) dominated runtime on surveys with tens of thousands of paths.
  n <- nrow(e$paths)
  profiles <- vector("list", n)
  q <- matrix(NA_real_, n, 5L)
  for (i in seq_len(n)) {
    prof <- assemble_path_distribution(e$components[[i]])
    profiles[[i]] <- prof
    q[i, ] <- weighted_quantile(prof$burden, prof$weight, c(0, .25, .5, .75, 1))
  }
  out <- tibble::tibble(
    path_id = e$paths$path_id,
    terminates_early = e$paths$terminates_early,
    n_gates = e$paths$n_gates,
    burden_min = q[, 1], burden_p25 = q[, 2], burden_median = q[, 3],
    burden_p75 = q[, 4], burden_max = q[, 5],
    profile = profiles
  )
  u <- e$unresolved %||% tibble::tibble(path_id = integer(0), question_id = character(0),
                                        reason = character(0))
  attr(out, "unresolved") <- u
  attr(out, "approximations") <- u[grepl("approximation|max_condition_states|keeps unanswered",
                                         u$reason), ]
  out
}

#' Shared setup for the path-burden family: parse, score, resolve paths, and
#' compute per-path burden components (base / loops / display distribution).
#' Returns a list with `paths` and `components` (one `list(base, loops,
#' display_dist)` per path), plus `blocks`, `scored` and `scheme`.
#' `paths`, `scored`, `blocks` and `parsed_dl` may be passed in precomputed
#' (internal reuse by [burden_report()]); each defaults to `NULL` and is then
#' computed here.
#' @noRd
burden_engine <- function(qsf, scheme = gfs_scheme(), max_paths = 10000L,
                          paths = NULL, scored = NULL, blocks = NULL,
                          parsed_dl = NULL, max_condition_states = 10000L,
                          overrides = NULL, choice_tasks = NULL,
                          field_domains = NULL, loop_weights = NULL,
                          respect_force_response = TRUE) {
  if (is.null(paths))  paths  <- resolve_paths(qsf, max_paths = max_paths,
                                               field_domains = field_domains)
  if (is.null(scored)) scored <- score_burden(parse_qsf(qsf), scheme = scheme)
  scored <- adjust_scores(scored, scheme, choice_tasks, overrides)
  if (is.null(blocks)) blocks <- resolve_live_blocks(qsf)

  gfs    <- stats::setNames(scored$gfs_points, scored$question_id)
  stype  <- stats::setNames(scored$std_type,  scored$question_id)
  qblock <- stats::setNames(scored$block_id,  scored$question_id)

  parsed <- parsed_dl %||% parse_all_display_logic(qsf, scored)

  loop_blocks <- stats::setNames(blocks$loop_max, blocks$block_id)
  loop_blocks <- loop_blocks[!is.na(loop_blocks)]
  validate_loop_weights(loop_weights, blocks)
  fmap   <- force_response_map(qsf)
  forced <- if (isTRUE(respect_force_response)) names(fmap)[fmap] else character(0)
  nopt   <- stats::setNames(scored$n_options, scored$question_id)

  memo <- new.env(parent = emptyenv())
  components <- lapply(seq_len(nrow(paths)), function(i) {
    one_path_components(
      q_always = paths$q_always[[i]], q_maybe = paths$q_maybe[[i]],
      block_ids = paths$block_ids[[i]],
      parsed = parsed, gfs = gfs, stype = stype,
      qblock = qblock, loop_blocks = loop_blocks, memo = memo,
      max_condition_states = max_condition_states,
      loop_weights = loop_weights, forced = forced, nopt = nopt
    )
  })
  unres <- do.call(rbind, lapply(seq_along(components), function(i) {
    u <- components[[i]]$unresolved
    if (!nrow(u)) return(NULL)
    data.frame(path_id = paths$path_id[i], u, stringsAsFactors = FALSE)
  }))
  unresolved <- tibble::as_tibble(unres %||% data.frame(
    path_id = integer(0), question_id = character(0), reason = character(0)))

  list(paths = paths, components = components, unresolved = unresolved,
       blocks = blocks, scored = scored, scheme = scheme)
}

#' Parse the `DisplayLogic` tree of every question that has one, keyed by
#' QuestionID. Shared by `burden_engine()` and `dl_certainty()` so the survey's
#' display-logic trees parse once per `burden_report()`, not twice.
#' @noRd
parse_all_display_logic <- function(qsf, scored) {
  sq  <- qsf_elements(qsf, "SQ")
  raw <- stats::setNames(sq, vapply(sq, function(p) p$QuestionID %||% NA_character_, character(1)))
  parsed <- list()
  for (qid in scored$question_id[scored$has_display_logic]) {
    dl <- raw[[qid]]$DisplayLogic
    if (!is.null(dl)) parsed[[qid]] <- parse_display_logic(dl)
  }
  parsed
}

#' Convolve a path's components into a burden distribution (loops uniform 1..max).
#' @noRd
assemble_path_distribution <- function(cp) {
  d <- bw_df(cp$base, 1)
  for (lp in cp$loops) {
    w <- lp$w %||% rep(1 / lp$n, lp$n)
    d <- convolve_dist(d, bw_df(lp$per_iter * seq_len(lp$n), w))
  }
  d <- convolve_dist(d, cp$display_dist)
  # new_tibble() skips tibble()'s per-call name checks; called once per path.
  tibble::new_tibble(list(burden = d$burden, weight = d$weight),
                     nrow = length(d$burden))
}

#' Burden components for one flow path: base, loops, display-logic distribution.
#' @return list(base, loops = named list of list(per_iter, n), display_dist df)
#' @noRd
one_path_components <- function(q_always, q_maybe, block_ids,
                                parsed, gfs, stype, qblock, loop_blocks,
                                memo = new.env(parent = emptyenv()),
                                max_condition_states = EXACT_CAP,
                                loop_weights = NULL, forced = character(0),
                                nopt = NULL) {
  loop_bids <- intersect(block_ids, names(loop_blocks))
  loop_qids <- names(qblock)[qblock %in% loop_bids]
  all_loop_qids <- names(qblock)[qblock %in% names(loop_blocks)]
  shown_q <- c(q_always, q_maybe)
  # forced-response triggers count as answered only where the route shows them
  forced_all <- forced
  forced <- intersect(forced_all, q_always)

  q_always_main <- setdiff(q_always, loop_qids)
  q_maybe_main  <- setdiff(q_maybe,  loop_qids)
  base <- sum(gfs[q_always_main], na.rm = TRUE)
  unres <- list()
  flag <- function(q, why) unres[[length(unres) + 1L]] <<- data.frame(
    question_id = q, reason = why, stringsAsFactors = FALSE)

  loops <- list(); units <- list()
  for (bid in loop_bids) {
    n  <- loop_blocks[[bid]]
    w  <- loop_weights[[bid]]
    lq <- intersect(names(qblock)[qblock == bid], shown_q)
    lcond <- intersect(lq, intersect(q_maybe, names(parsed)))
    if (!length(lcond) && !is.function(w)) {
      loops[[bid]] <- list(per_iter = sum(gfs[lq], na.rm = TRUE), n = n,
                           w = if (is.null(w)) NULL else w / sum(w))
      next
    }
    g <- classify_loop_gates(lcond, bid, parsed, qblock)
    other_loop <- g$shared[!startsWith(g$shared, "@") & g$shared %in% all_loop_qids]
    for (q in lcond) if (any(parsed[[q]]$vars %in% other_loop)) flag(q, "trigger in another loop")
    units[[bid]] <- list(bid = bid, n = n, w = w, always = setdiff(lq, lcond),
                         cond = lcond, iter = g$iter, shared = g$shared,
                         position = g$position, off_iter = setdiff(g$iter, shown_q))
  }

  cond <- q_maybe_main[q_maybe_main %in% names(parsed)]
  for (q in cond) {
    v <- parsed[[q]]$vars
    if ("@@iter" %in% v) flag(q, "loop position outside loop")
    if (any(v %in% all_loop_qids)) flag(q, "trigger inside a loop")
  }
  # conditionally shown forced triggers keep an unanswered state in the profile
  all_cond <- c(cond, unlist(lapply(units, `[[`, "cond")))
  trig_q <- unique(unlist(lapply(all_cond, function(q) parsed[[q]]$vars)))
  nested_forced <- intersect(intersect(trig_q, all_cond), forced_all)
  for (q in nested_forced) flag(q, "conditional forced trigger keeps unanswered state (profile only)")

  display_dist <- bw_df(0, 1)
  nodes <- c(cond, if (length(units)) paste0("loop:", names(units)))
  if (length(nodes) > 0) {
    parsed2 <- parsed
    for (bid in names(units)) parsed2[[paste0("loop:", bid)]] <- list(vars = units[[bid]]$shared)
    for (grp in connected_components(nodes, parsed2)) {
      lnodes <- grp[startsWith(grp, "loop:")]
      qgrp   <- setdiff(grp, lnodes)
      us     <- units[sub("^loop:", "", lnodes)]
      gvars <- unique(c(unlist(lapply(qgrp, function(q) parsed[[q]]$vars)),
                        unlist(lapply(us, `[[`, "shared"))))
      disp  <- intersect(q_always, unlist(lapply(qgrp, function(q) parsed[[q]]$displayed)))
      # trigger questions this path never shows: fixed as unanswered
      off   <- gvars[!startsWith(gvars, "@") & !gvars %in% shown_q]
      fn_w  <- any(vapply(us, function(u) is.function(u$w), logical(1)))
      key <- paste0(max_condition_states, "|", paste(sort(gvars), collapse = ","), "|",
                    paste(sort(grp), collapse = ","), "|",
                    paste(sort(disp), collapse = ","), "|",
                    paste(sort(off), collapse = ","), "|",
                    paste(sort(intersect(forced, c(gvars, unlist(lapply(us, `[[`, "iter"))))),
                          collapse = ","), "|",
                    paste(vapply(us, function(u) paste(u$bid, u$n,
                                                       if (is.function(u$w)) "fn" else paste(u$w, collapse = "/"),
                                                       paste(sort(u$always), collapse = "+"),
                                                       paste(sort(u$cond), collapse = "+"),
                                                       paste(sort(u$off_iter), collapse = "+")),
                                 character(1)), collapse = ";"))
      cc <- if (fn_w) NULL else memo[[key]]
      if (is.null(cc)) {
        cc <- if (!length(us)) {
          component_dist(qgrp, gvars, parsed, gfs, stype, q_always, off = off,
                         exact_cap = max_condition_states, forced = forced, nopt = nopt)
        } else {
          component_dist_loop(qgrp, us, gvars, parsed, gfs, stype, q_always, off = off,
                              exact_cap = max_condition_states, forced = forced, nopt = nopt)
        }
        if (!fn_w) memo[[key]] <- cc
      }
      ap <- attr(cc, "approx")
      if (!is.null(ap) && nrow(ap)) for (r in seq_len(nrow(ap))) flag(ap$question_id[r], ap$reason[r])
      display_dist <- convolve_dist(display_dist, cc)
    }
  }

  unresolved <- if (length(unres)) do.call(rbind, unres) else
    data.frame(question_id = character(0), reason = character(0), stringsAsFactors = FALSE)
  list(base = base, loops = loops, display_dist = display_dist,
       unresolved = unique(unresolved))
}

#' Exact distribution of a coupling component that contains Loop & Merge
#' units: enumerate the joint state of the shared gates (one state for every
#' iteration and for the non-loop questions); for each, add the non-loop
#' questions' burden and each loop's contribution given that state.
#' Approximations are returned in `attr(, "approx")` (question_id, reason).
#' @noRd
component_dist_loop <- function(qgrp, units, gvars, parsed, gfs, stype, q_always,
                                off = character(0), exact_cap = EXACT_CAP,
                                forced = character(0), nopt = NULL) {
  gvars <- setdiff(gvars, "@@iter")
  deps  <- c(qgrp, unlist(lapply(units, `[[`, "cond")))
  states <- lapply(gvars, function(v) gate_states(v, deps, parsed, stype, off, forced, nopt))
  names(states) <- gvars
  total <- prod(vapply(states, length, integer(1)))
  shown0 <- stats::setNames(rep(TRUE, length(q_always)), q_always)
  # iteration-gate groups per loop: built once, independent of the shared state
  for (k in seq_along(units)) {
    units[[k]]$icomps <- loop_iter_components(units[[k]], parsed, stype, off, exact_cap, forced, nopt)
  }
  work <- sum(vapply(units, loop_unit_work, numeric(1)))
  approx <- do.call(rbind, lapply(units, function(u) {
    a <- Filter(function(cmp) cmp$approx, u$icomps)
    if (!length(a)) return(NULL)
    data.frame(question_id = unlist(lapply(a, `[[`, "q")),
               reason = "iteration gates above max_condition_states (held permissive)",
               stringsAsFactors = FALSE)
  }))

  if (total * max(1, work) > exact_cap) {
    # above the limit: shared gates held permissive
    d <- if (length(qgrp)) component_dist_fallback(qgrp, parsed, gfs, stype, q_always, off) else bw_df(0, 1)
    for (u in units) {
      d <- convolve_dist(d, loop_unit_dist(u, list(), parsed, gfs, q_always,
                                           permissive = u$shared))
    }
    attr(d, "approx") <- rbind(approx, data.frame(
      question_id = c(qgrp, unlist(lapply(units, `[[`, "cond"))),
      reason = "loop component above max_condition_states (shared gates held permissive)",
      stringsAsFactors = FALSE))
    return(d)
  }

  grid  <- if (length(states)) expand.grid(lapply(states, seq_along), KEEP.OUT.ATTRS = FALSE) else
    data.frame(.row = 1L)   # no shared gates: a single (empty) shared state
  gcols <- lapply(grid, as.integer)
  preds <- lapply(qgrp, function(q) parsed[[q]]$predicate)
  gq    <- vapply(qgrp, function(q) gfs[[q]] %||% 0, numeric(1))
  trig  <- order_triggers(intersect(gvars, qgrp), parsed)
  tpreds <- lapply(trig, function(q) parsed[[q]]$predicate)
  lmemo <- new.env(parent = emptyenv())

  parts <- lapply(seq_len(nrow(grid)), function(r) {
    s <- lapply(seq_along(gvars), function(j) states[[j]][[gcols[[j]][r]]])
    names(s) <- gvars
    s <- settle_hidden_triggers(s, trig, tpreds, shown0)
    b0 <- 0
    for (i in seq_along(qgrp)) if (isTRUE(preds[[i]](s, shown0))) b0 <- b0 + gq[i]
    d <- bw_df(b0, 1)
    for (u in units) {
      k <- paste(u$bid, paste(vapply(u$shared, function(v) paste(s[[v]], collapse = "+"),
                                     character(1)), collapse = "|"))
      ld <- if (is.function(u$w)) NULL else lmemo[[k]]
      if (is.null(ld)) {
        ld <- loop_unit_dist(u, s[u$shared], parsed, gfs, q_always)
        if (!is.function(u$w)) lmemo[[k]] <- ld
      }
      d <- convolve_dist(d, ld)
    }
    d
  })
  out <- mix_dists(parts, rep(1 / length(parts), length(parts)))
  attr(out, "approx") <- approx
  out
}

#' Order trigger questions so each comes after the triggers its own condition
#' reads (cycles keep their input order at the end).
#' @noRd
order_triggers <- function(trig, parsed) {
  if (length(trig) < 2L) return(trig)
  deps <- lapply(trig, function(t) intersect(parsed[[t]]$vars %||% character(0), setdiff(trig, t)))
  names(deps) <- trig
  out <- character(0); left <- trig
  repeat {
    ready <- left[vapply(left, function(t) all(deps[[t]] %in% out), logical(1))]
    if (!length(ready)) break
    out <- c(out, ready); left <- setdiff(left, ready)
    if (!length(left)) break
  }
  c(out, left)
}

#' A loop's conditional questions grouped by the iteration gates they share,
#' each group with its enumerated gate states. A group whose joint states
#' exceed `exact_cap` holds its gates permissive and is reported.
#' @noRd
loop_iter_components <- function(u, parsed, stype, off, exact_cap, forced, nopt) {
  off_u <- unique(c(off, u$off_iter))
  plist <- stats::setNames(lapply(u$cond, function(q)
    list(vars = intersect(parsed[[q]]$vars %||% character(0), u$iter))), u$cond)
  comps <- if (length(u$cond)) connected_components(u$cond, plist) else list()
  lapply(comps, function(cq) {
    gates <- unique(unlist(lapply(cq, function(q) plist[[q]]$vars)))
    st <- lapply(gates, function(v) gate_states(v, cq, parsed, stype, off_u, forced, nopt))
    names(st) <- gates
    m <- prod(vapply(st, length, integer(1)))
    list(q = cq, gates = gates, states = st, m = m, approx = m > exact_cap,
         trig = order_triggers(intersect(gates, cq), parsed))
  })
}

#' Enumeration work of one loop unit per shared state.
#' @noRd
loop_unit_work <- function(u) {
  per <- sum(vapply(u$icomps, function(cmp) if (cmp$approx) 1 else cmp$m, numeric(1)))
  max(1, per) * (if (isTRUE(u$position)) u$n else 1)
}

#' One Loop & Merge block's total contribution given the shared-gate state
#' `s`: iteration gates take a fresh, equally weighted state each iteration
#' (groups of questions sharing iteration gates are enumerated jointly and
#' convolved); iteration j uses `@@iter = j`; n iterations are the
#' convolution of the first n per-iteration distributions, mixed over n by the
#' loop weights.
#' @noRd
loop_unit_dist <- function(u, s, parsed, gfs, q_always, permissive = character(0)) {
  shown0 <- stats::setNames(rep(TRUE, length(q_always)), q_always)
  alw <- sum(gfs[u$always], na.rm = TRUE)

  comp_dist <- function(cmp, j) {
    perm <- if (cmp$approx) c(permissive, cmp$gates) else permissive
    st <- if (cmp$approx) list() else cmp$states
    grid <- if (length(st)) expand.grid(lapply(st, seq_along), KEEP.OUT.ATTRS = FALSE) else
      data.frame(.row = 1L)
    m <- nrow(grid)
    gcols <- lapply(grid, as.integer)
    preds <- lapply(cmp$q, function(q) parsed[[q]]$predicate)
    gc <- vapply(cmp$q, function(q) gfs[[q]] %||% 0, numeric(1))
    tpreds <- lapply(cmp$trig, function(q) parsed[[q]]$predicate)
    b <- vapply(seq_len(m), function(r) {
      a <- s
      for (k in seq_along(st)) a[[names(st)[k]]] <- st[[k]][[gcols[[k]][r]]]
      a[["@@iter"]] <- j
      a <- settle_hidden_triggers(a, cmp$trig, tpreds, shown0, perm)
      x <- 0
      for (i in seq_along(cmp$q)) if (isTRUE(preds[[i]](a, shown0, permissive = perm))) x <- x + gc[i]
      x
    }, numeric(1))
    group_sum(round(b, 1), rep(1 / m, m))
  }
  per_iter <- function(j) {
    d <- bw_df(alw, 1)
    for (cmp in u$icomps) d <- convolve_dist(d, comp_dist(cmp, j))
    d
  }

  w <- u$w
  if (is.function(w)) w <- check_loop_weight_vector(w(s), u$bid, u$n)
  if (is.null(w)) w <- rep(1, u$n)
  w <- w / sum(w)

  d1 <- per_iter(1L)
  same <- !isTRUE(u$position)
  tn <- d1
  parts <- list(); pw <- numeric(0)
  for (n in seq_len(u$n)) {
    if (n > 1L) tn <- convolve_dist(tn, if (same) d1 else per_iter(n))
    if (w[n] > 0) { parts[[length(parts) + 1L]] <- tn; pw <- c(pw, w[n]) }
  }
  mix_dists(parts, pw)
}

#' Mixture of (burden, weight) distributions with the given mixing weights.
#' @noRd
mix_dists <- function(parts, w) {
  b  <- unlist(lapply(parts, `[[`, "burden"))
  wt <- unlist(Map(function(p, x) p$weight / sum(p$weight) * x, parts, w))
  d  <- group_sum(round(b, 1), wt / sum(w))
  if (nrow(d) > 3000) d <- group_sum(round(d$burden / 5) * 5, d$weight)
  d
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
component_dist <- function(grp, gvars, parsed, gfs, stype, q_always, exact_cap = EXACT_CAP,
                           off = character(0), forced = character(0), nopt = NULL) {
  gvars <- setdiff(gvars, "@@iter")   # outside a loop the position literal is FALSE
  states <- lapply(gvars, function(v) gate_states(v, grp, parsed, stype, off, forced, nopt))
  names(states) <- gvars
  total <- prod(vapply(states, length, integer(1)))

  if (length(gvars) <= 1 || total <= exact_cap) {
    return(component_dist_exact(grp, gvars, states, parsed, gfs, q_always))
  }
  d <- component_dist_fallback(grp, parsed, gfs, stype, q_always, off)
  attr(d, "approx") <- data.frame(question_id = grp,
    reason = "primary-gate approximation above max_condition_states", stringsAsFactors = FALSE)
  d
}

#' Hidden triggers are unanswered: a conditional question that is also a gate
#' and whose own condition fails under `assign` is reset to unanswered
#' (`character(0)`), repeated until nothing changes, so a question never shows
#' because of an answer to a question that was not displayed.
#' @noRd
settle_hidden_triggers <- function(assign, trig, trig_preds, shown0, permissive = character(0)) {
  if (!length(trig)) return(assign)
  for (pass in seq_along(trig)) {
    changed <- FALSE
    for (i in seq_along(trig)) {
      t <- trig[i]
      if (length(assign[[t]]) && !is.logical(assign[[t]]) &&
          !isTRUE(trig_preds[[i]](assign, shown0, permissive = permissive))) {
        assign[[t]] <- character(0); changed <- TRUE
      }
    }
    if (!changed) break
  }
  assign
}

#' Exact joint enumeration of a component's gate states.
#' @noRd
component_dist_exact <- function(grp, gvars, states, parsed, gfs, q_always) {
  shown0 <- stats::setNames(rep(TRUE, length(q_always)), q_always)
  grid <- expand.grid(lapply(states, seq_along), KEEP.OUT.ATTRS = FALSE)
  n <- nrow(grid)

  # column-wise integer indices (df `[r, j]` per cell is slow in a tight loop),
  # per-question burden and predicate looked up once, not per grid row.
  gcols   <- lapply(grid, as.integer)
  ng      <- seq_along(gvars)
  preds   <- lapply(grp, function(q) parsed[[q]]$predicate)
  gfs_grp <- vapply(grp, function(q) gfs[[q]] %||% 0, numeric(1))
  trig    <- order_triggers(intersect(gvars, grp), parsed)   # conditional gates, in dependency order
  tpreds  <- lapply(trig, function(q) parsed[[q]]$predicate)

  burdens <- vapply(seq_len(n), function(r) {
    assign <- lapply(ng, function(j) states[[j]][[gcols[[j]][r]]])
    names(assign) <- gvars
    assign <- settle_hidden_triggers(assign, trig, tpreds, shown0)
    b <- 0
    for (qi in seq_along(grp)) {
      if (isTRUE(preds[[qi]](assign, shown0))) b <- b + gfs_grp[qi]
    }
    b
  }, numeric(1))

  d <- group_sum(round(burdens, 1), rep(1, n))
  d$weight <- d$weight / n
  d
}

#' Primary-gate approximation for a component too large to enumerate exactly.
#' @noRd
component_dist_fallback <- function(grp, parsed, gfs, stype, q_always, off = character(0)) {
  owner <- vapply(grp, function(q) parsed[[q]]$vars[1], character(1))
  by_gate <- split(grp, owner)
  d <- bw_df(0, 1)
  for (v in names(by_gate)) {
    dep <- sort(by_gate[[v]])
    d <- convolve_dist(d, gate_component(v, dep, parsed, gfs, stype, q_always, off))
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
  d <- bw_df(cp$base, 1)
  for (lp in cp$loops) {
    d <- convolve_dist(d, bw_df(lp$per_iter * seq_len(lp$n), 1 / lp$n))
  }
  d <- convolve_dist(d, cp$display_dist)
  tibble::tibble(burden = d$burden, weight = d$weight)
}

#' Burden contribution distribution from one gate and the questions it owns.
#' @return data.frame(burden, weight)
#' @noRd
gate_component <- function(v, deps, parsed, gfs, stype, q_always, off = character(0)) {
  states <- gate_states(v, deps, parsed, stype, off)
  other_vars <- setdiff(unique(unlist(lapply(deps, function(q) parsed[[q]]$vars))), v)
  # never-shown trigger questions are fixed as unanswered, not held permissive
  other_off  <- intersect(other_vars, off)
  other_vars <- setdiff(other_vars, other_off)
  fixed_off  <- stats::setNames(rep(list(character(0)), length(other_off)), other_off)
  shown0 <- stats::setNames(rep(TRUE, length(q_always)), q_always)

  burdens <- vapply(states, function(s) {
    assign <- c(stats::setNames(list(s), v), fixed_off)
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

#' A bare two-column (burden, weight) data frame, skipping the `data.frame()`
#' constructor's name/row-name/coercion checks -- this is built ~1000+ times per
#' `burden_report()` on a survey with display logic.
#' @noRd
bw_df <- function(burden, weight) {
  n <- max(length(burden), length(weight))
  if (length(burden) != n) burden <- rep(burden, length.out = n)
  if (length(weight) != n) weight <- rep(weight, length.out = n)
  structure(list(burden = burden, weight = weight),
            class = "data.frame", row.names = .set_row_names(n))
}

#' Fast group-sum of weights by (rounded) burden value.
#' @noRd
group_sum <- function(burden, weight) {
  k <- as.integer(round(burden * 10))
  u <- sort.int(unique(k))
  idx <- match(k, u)
  w <- as.numeric(rowsum(weight, idx))   # reorder = TRUE: rows in idx (=u) order
  bw_df(u / 10, w)
}

#' Possible states of a gate variable.
#' @noRd
gate_states <- function(v, deps, parsed, stype, off = character(0),
                        forced = character(0), nopt = NULL) {
  if (v %in% off) return(list(character(0)))   # never shown: unanswered
  if (startsWith(v, "@")) {
    cmp <- unlist(lapply(deps, function(q) parsed[[q]]$fields[[v]]), recursive = FALSE)
    if (!length(cmp)) return(list(TRUE, FALSE))  # free binary gate
    ops    <- vapply(cmp, `[[`, character(1), "op")
    values <- vapply(cmp, `[[`, character(1), "value")
    return(as.list(field_value_classes(ops, values)))
  }
  refs <- unique(unlist(lapply(deps, function(q) lits_refs(parsed[[q]], v))))
  if (length(refs) == 0) return(list(TRUE, FALSE))
  # a shown forced-response trigger is always answered: when its referenced
  # choices cover all its choices, "none of them" cannot occur
  n_all <- if (is.null(nopt)) NA_integer_ else (nopt[[v]] %||% NA_integer_)
  drop_none <- v %in% forced && !is.na(n_all) && length(refs) >= n_all
  if (identical(stype[[v]] %||% "", "single_choice")) {
    st <- lapply(refs, identity)
    if (!drop_none) st <- c(st, list(character(0)))
    st
  } else {
    if (length(refs) > 6) { refs <- refs[seq_len(6)]; drop_none <- FALSE }
    subs <- unlist(lapply(0:length(refs), function(k) utils::combn(refs, k, simplify = FALSE)),
                   recursive = FALSE)
    if (drop_none) subs <- subs[-1L]   # the empty subset
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
