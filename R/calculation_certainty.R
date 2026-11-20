#' Where the burden calculation is exact, and where it rests on assumptions
#'
#' `burden_report()` propagates an established item score through a survey's
#' flow and display logic. Some of that propagation is exact (a fixed block
#' sequence, a loop with an explicit cap); some rests on documented assumptions
#' (the gate-independence approximation for large display-logic components, the
#' independence of separate coupling components). This function reports the
#' split so a reader can see which parts of the output depend on those
#' assumptions.
#'
#' "Exact" is used in two narrow senses here, and neither means the result
#' matches the live survey:
#' \itemize{
#'   \item a path counted in `n_exact` has no unresolved display-logic
#'     question on it (every question is always shown or ruled out);
#'   \item a display-logic question counted in `n_exact` was enumerated in
#'     full: every joint state of its gates that the model represents was
#'     scored, rather than approximated.
#' }
#' Fidelity to the original survey's full logic is established by neither:
#' branch conditions are not checked against each other, embedded-data
#' conditions are treated as free, and unusual Qualtrics constructs may not be
#' modelled at all. The breakdown describes these modelling diagnostics, not
#' an overall certificate of correctness.
#'
#' @param qsf A path to a `.qsf`, or a `qsf_raw` object from [read_qsf()].
#' @param scheme A [gfs_scheme()] list.
#' @param max_condition_states Maximum joint condition-state combinations
#'   enumerated in full per connected display-logic component (default 10000).
#'   Must be a positive finite whole number. Larger components use the
#'   primary-gate approximation. This is separate from `max_paths` and does
#'   not remove other modelling assumptions. When precomputed results are
#'   supplied, use the same limit that generated those results.
#' @param max_paths Passed to [resolve_paths()].
#' @param paths,scored,blocks,parsed_dl Optional precomputed [resolve_paths()],
#'   [score_burden()], [resolve_live_blocks()] and parsed display-logic results
#'   for this `qsf` (internal reuse by [burden_report()]; `NULL` computes them
#'   here, leaving the public behaviour unchanged).
#' @param overrides Optional named numeric vector of GfS+ points that replace
#'   the computed score of the named questions, e.g. `c(QID51 = 10)`; counted
#'   as `manual` in `scores`. See [burden_report()].
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
#'   [resolve_flow()]: branches on a declared field take only outcomes those
#'   values produce, so an unreachable "none matches" path is dropped.
#' @param choice_tasks Optional data frame declaring stated-choice tasks
#'   (`question_id`, `n_alternatives`, `n_attributes`), scored by the GfS
#'   stated-choice rule. Counted as `manual`. See
#'   [burden_report()].
#'
#' @return An object of class `calculation_certainty` (list):
#'   \describe{
#'     \item{paths}{`n_full`, `n_exact` (no unresolved display-logic conditions),
#'       `n_with_unresolved`, and a `per_path` tibble.}
#'     \item{branches}{One row per flow `Branch`, with the trigger variable(s).
#'       Both outcomes of every branch are always enumerated, so a branch is not
#'       an approximation -- but which outcome a given respondent takes is
#'       unknown before fieldwork.}
#'     \item{randomisers}{One row per `BlockRandomizer`: `flow_id`,
#'       `n_children`, `subset` (how many it shows; `NA` when not readable),
#'       `shows_blocks` (`FALSE` for a randomiser of embedded-data
#'       assignments) and `enumerated` (`TRUE` when the subset was read, so
#'       each combination of elements is a separate path).}
#'     \item{display_logic}{`n_conditional` questions gated by an unresolved
#'       condition on some full path; `n_exact` scored by exact joint
#'       enumeration of their gate states; `n_approx` scored with the
#'       primary-gate approximation; component counts;
#'       `cross_component_independence` (`TRUE` when >1 coupling component is
#'       convolved as independent); and `n_binary_field_gates`, the stored
#'       fields compared with an operator the package cannot evaluate (such as
#'       `Contains`), each treated as a free true/false condition.}
#'     \item{loops}{`n_known` loop blocks with an explicit iteration cap,
#'       `n_unknown` with a dynamic/unknown bound, and a `bounds` tibble.}
#'     \item{scores}{Counts of `score_flag`: `auto` (confident structural
#'       mapping), `inferred` (mapping needs an assumption), `manual`,
#'       `unknown`.}
#'   }
#'
#' @examples
#' \donttest{
#' qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
#'                          package = "surveyBurden")
#' calculation_certainty(qsf_path)
#' }
#' @export
calculation_certainty <- function(qsf, scheme = gfs_scheme(), max_paths = 10000L,
                                  paths = NULL, scored = NULL, blocks = NULL,
                                  parsed_dl = NULL, max_condition_states = 10000L,
                                  overrides = NULL, choice_tasks = NULL,
                                  field_domains = NULL, loop_weights = NULL,
                                  respect_force_response = TRUE) {
  validate_condition_states(max_condition_states)
  qsf    <- if (inherits(qsf, "qsf_raw")) qsf else read_qsf(qsf)
  if (is.null(paths))  paths  <- resolve_paths(qsf, max_paths = max_paths,
                                               field_domains = field_domains)
  if (is.null(scored)) scored <- score_burden(parse_qsf(qsf), scheme = scheme)
  scored <- adjust_scores(scored, scheme, choice_tasks, overrides)
  if (is.null(blocks)) blocks <- resolve_live_blocks(qsf)
  full   <- paths[!paths$terminates_early, ]

  # --- paths: exact vs carrying an unresolved display-logic condition ---
  n_maybe <- vapply(full$q_maybe, length, integer(1))
  paths_cert <- list(
    n_full            = nrow(full),
    n_exact           = sum(n_maybe == 0L),
    n_with_unresolved = sum(n_maybe > 0L),
    per_path          = tibble::tibble(
      path_id = full$path_id, n_maybe = n_maybe, n_gates = full$n_gates
    )
  )

  # --- branches: trigger variable(s); both outcomes always enumerated ---
  br <- list()
  flow_walk(qsf_flow(qsf)[["Flow"]], function(n) {
    if (identical(n$Type, "Branch")) {
      v <- tryCatch(parse_display_logic(n$BranchLogic)$vars,
                    error = function(e) character(0))
      br[[length(br) + 1L]] <<- list(
        flow_id = n$FlowID %||% NA_character_,
        trigger = if (length(v)) paste(unique(v), collapse = " / ") else "(unparsed)"
      )
    }
  })
  branch_tbl <- tibble::tibble(
    flow_id = vapply(br, `[[`, character(1), "flow_id"),
    trigger = vapply(br, `[[`, character(1), "trigger")
  )

  # --- randomisers: subset honoured (each combination a path) or not ---
  rn <- list()
  flow_walk(qsf_flow(qsf)[["Flow"]], function(n) {
    if (identical(n$Type, "BlockRandomizer")) {
      ch <- n[["Flow"]] %||% list()
      m  <- randomiser_subset(n)
      rn[[length(rn) + 1L]] <<- list(
        flow_id = n$FlowID %||% NA_character_, n_children = length(ch),
        subset = m, shows_blocks = flow_has_blocks(ch), enumerated = !is.na(m))
    }
  })
  rand_tbl <- tibble::tibble(
    flow_id      = vapply(rn, `[[`, character(1), "flow_id"),
    n_children   = vapply(rn, `[[`, integer(1), "n_children"),
    subset       = vapply(rn, `[[`, integer(1), "subset"),
    shows_blocks = vapply(rn, `[[`, logical(1), "shows_blocks"),
    enumerated   = vapply(rn, `[[`, logical(1), "enumerated")
  )

  # --- display logic: exact enumeration vs primary-gate approximation ---
  dl_cert <- dl_certainty(qsf, scored, full, exact_cap = max_condition_states,
                          parsed_dl = parsed_dl)

  # --- loops ---
  lb  <- blocks[blocks$in_loop & !is.na(blocks$loop_max), ]
  lbu <- blocks[blocks$in_loop & is.na(blocks$loop_max), ]
  validate_loop_weights(loop_weights, blocks)
  cond_all <- unique(unlist(full$q_maybe))
  loop_cond <- intersect(cond_all[cond_all %in% scored$question_id[scored$block_id %in% lb$block_id]],
                         scored$question_id[scored$has_display_logic])
  # conditionally shown forced-response triggers keep an unanswered state in
  # the structural profile (path_burden_traversals() has no such approximation)
  pdl <- parsed_dl %||% parse_all_display_logic(qsf, scored)
  fmap <- force_response_map(qsf)
  trig <- unique(unlist(lapply(cond_all[cond_all %in% names(pdl)], function(q) pdl[[q]]$vars)))
  nested_forced <- if (isTRUE(respect_force_response))
    intersect(intersect(trig, cond_all), names(fmap)[fmap]) else character(0)
  loops_cert <- list(
    n_known   = nrow(lb),
    n_unknown = nrow(lbu),
    bounds    = tibble::tibble(block_id = lb$block_id,
                               block_name = lb$block_name,
                               max_iter = lb$loop_max),
    n_loop_conditional  = length(loop_cond),
    weights             = if (is.null(loop_weights)) "uniform" else "user",
    nested_forced_gates = nested_forced
  )

  # --- item scores ---
  sf <- factor(scored$score_flag, levels = c("auto", "inferred", "manual", "unknown"))
  scores_cert <- as.list(table(sf))
  scores_cert <- lapply(scores_cert, as.integer)

  structure(list(
    survey_name   = qsf$SurveyEntry$SurveyName %||% NA_character_,
    paths         = paths_cert,
    branches      = branch_tbl,
    randomisers   = rand_tbl,
    display_logic = dl_cert,
    loops         = loops_cert,
    scores        = scores_cert
  ), class = "calculation_certainty")
}

#' Exact-vs-approximation split of the display-logic gates, matching the
#' component logic in [path_burden_profile()].
#' @noRd
dl_certainty <- function(qsf, scored, full, exact_cap = EXACT_CAP, parsed_dl = NULL) {
  parsed <- parsed_dl %||% parse_all_display_logic(qsf, scored)
  stype <- stats::setNames(scored$std_type, scored$question_id)

  cond <- unique(unlist(full$q_maybe))
  cond <- cond[cond %in% names(parsed)]

  exact_q <- character(0); approx_q <- character(0)
  n_comp <- 0L; n_exact_comp <- 0L; n_approx_comp <- 0L
  if (length(cond)) {
    for (grp in connected_components(cond, parsed)) {
      n_comp <- n_comp + 1L
      gvars  <- unique(unlist(lapply(grp, function(q) parsed[[q]]$vars)))
      states <- lapply(gvars, function(v) gate_states(v, grp, parsed, stype))
      total  <- prod(vapply(states, length, numeric(1)))
      if (length(gvars) <= 1 || total <= exact_cap) {
        exact_q <- c(exact_q, grp); n_exact_comp <- n_exact_comp + 1L
      } else {
        approx_q <- c(approx_q, grp); n_approx_comp <- n_approx_comp + 1L
      }
    }
  }

  list(
    max_condition_states        = exact_cap,
    n_conditional               = length(cond),
    n_exact                     = length(exact_q),
    n_approx                    = length(approx_q),
    approx_questions            = approx_q,
    n_components                = n_comp,
    n_exact_components          = n_exact_comp,
    n_approx_components         = n_approx_comp,
    cross_component_independence = n_comp > 1L,
    n_binary_field_gates        = length(unique(grep("^@[?]",
      unlist(lapply(cond, function(q) parsed[[q]]$vars)), value = TRUE)))
  )
}

#' @export
print.calculation_certainty <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

#' @export
format.calculation_certainty <- function(x, ...) {
  cli::cli_fmt(print_calculation_certainty_body(x), collapse = FALSE)
}

# Plain-language lines shared by print.calculation_certainty() and the
# certainty section of print.burden_report(). Returns a named list of
# character vectors (routes, display, loops, scores). Braces are doubled so
# the text can go through cli.
certainty_lines <- function(x) {
  p <- x$paths; d <- x$display_logic; l <- x$loops; s <- x$scores
  esc <- function(v) gsub("}", "}}", gsub("{", "{{", v, fixed = TRUE), fixed = TRUE)
  num <- function(v) format(v, big.mark = ",", scientific = FALSE, trim = TRUE)
  pl  <- function(n, one, many) if (n == 1) one else many

  # routes
  routes <- if (p$n_full == 0L) {
    "There are no complete routes."
  } else {
    on <- if (p$n_with_unresolved == 0L) {
      "No item is shown only if earlier answers meet a display condition."
    } else {
      who <- if (p$n_full == 1L) "it" else if (p$n_with_unresolved == p$n_full) {
        if (p$n_full == 2L) "both" else "all of them"
      } else sprintf("%d of them", p$n_with_unresolved)
      sprintf("On %s, some items are shown only if earlier answers meet a display condition.",
              who)
    }
    c(sprintf("%d complete %s. %s", p$n_full, pl(p$n_full, "route", "routes"), on))
  }
  if (nrow(x$branches) > 0) {
    v <- unique(unlist(strsplit(x$branches$trigger, " / ", fixed = TRUE)))
    v <- v[v != "(unparsed)"]
    nb <- nrow(x$branches)
    routes <- c(routes, sprintf(
      "%d %s depend%s on answers given during the survey%s. Both outcomes of each branch are included.",
      nb, pl(nb, "branch", "branches"), if (nb == 1) "s" else "",
      if (length(v)) paste0(" (", esc(paste(v, collapse = ", ")), ")") else ""))
  }

  # display logic
  display <- if (d$n_conditional == 0L) {
    "No item has display logic that depends on earlier answers."
  } else {
    n <- d$n_conditional
    lim <- sprintf("(limit %s combinations per linked set)", num(d$max_condition_states))
    first <- sprintf("%d %s display logic.", n, pl(n, "item has", "items have"))
    ev <- if (d$n_exact == n) {
      sprintf("%s evaluated for every combination of answers %s.",
              if (n == 1) "It was" else sprintf("All %d were", n), lim)
    } else {
      sprintf("%d %s evaluated for every combination of answers %s.",
              d$n_exact, pl(d$n_exact, "was", "were"), lim)
    }
    ap <- if (d$n_approx == 0L) "None was approximated."
          else sprintf("%d %s approximated.", d$n_approx, pl(d$n_approx, "was", "were"))
    c(first, ev, ap)
  }
  if (isTRUE(d$cross_component_independence)) {
    display <- c(display, sprintf(
      "The %d unlinked sets of display conditions are combined as if independent.",
      d$n_components))
  }
  if (isTRUE(d$n_binary_field_gates > 0L)) {
    display <- c(display, sprintf(
      "%d stored %s used in a test the package cannot evaluate. Each is treated as true or false, and both outcomes are included.",
      d$n_binary_field_gates, pl(d$n_binary_field_gates, "field is", "fields are")))
  }

  # loops
  loops <- if (l$n_known + l$n_unknown == 0L) {
    "There are no Loop & Merge blocks."
  } else {
    out <- character(0)
    if (l$n_known > 0L) {
      b <- sprintf("%s: 0 to %s repetitions.", esc(l$bounds$block_name), l$bounds$max_iter)
      out <- c(out, paste(c(sprintf("%d Loop & Merge %s a fixed maximum.", l$n_known,
                                    pl(l$n_known, "block has", "blocks have")), b),
                          collapse = " "))
    }
    if (l$n_unknown > 0L) {
      out <- c(out, sprintf("%d Loop & Merge %s no fixed maximum.", l$n_unknown,
                            pl(l$n_unknown, "block has", "blocks have")))
    }
    out
  }

  scores <- sprintf("%d %s scored automatically, %d by inference, %d from user input, %d unscored.",
                    s$auto, pl(s$auto, "item", "items"), s$inferred, s$manual, s$unknown)
  list(routes = routes, display = display, loops = loops, scores = scores)
}

# Plain-language lines shared by print.calculation_certainty() and the
# certainty section of print.burden_report(). Returns a named list of
# character vectors (routes, display, loops, scores). Braces are doubled so
# the text can go through cli.
certainty_lines <- function(x) {
  p <- x$paths; d <- x$display_logic; l <- x$loops; s <- x$scores
  esc <- function(v) gsub("}", "}}", gsub("{", "{{", v, fixed = TRUE), fixed = TRUE)
  num <- function(v) format(v, big.mark = ",", scientific = FALSE, trim = TRUE)
  pl  <- function(n, one, many) if (n == 1) one else many

  # routes
  routes <- if (p$n_full == 0L) {
    "There are no complete routes."
  } else {
    on <- if (p$n_with_unresolved == 0L) {
      "No item is shown only if earlier answers meet a display condition."
    } else {
      who <- if (p$n_full == 1L) "it" else if (p$n_with_unresolved == p$n_full) {
        if (p$n_full == 2L) "both" else "all of them"
      } else sprintf("%d of them", p$n_with_unresolved)
      sprintf("On %s, some items are shown only if earlier answers meet a display condition.",
              who)
    }
    c(sprintf("%d complete %s. %s", p$n_full, pl(p$n_full, "route", "routes"), on))
  }
  if (nrow(x$branches) > 0) {
    v <- unique(unlist(strsplit(x$branches$trigger, " / ", fixed = TRUE)))
    v <- v[v != "(unparsed)"]
    nb <- nrow(x$branches)
    routes <- c(routes, sprintf(
      "%d %s depend%s on answers given during the survey%s. Both outcomes of each branch are included.",
      nb, pl(nb, "branch", "branches"), if (nb == 1) "s" else "",
      if (length(v)) paste0(" (", esc(paste(v, collapse = ", ")), ")") else ""))
  }

  # display logic
  display <- if (d$n_conditional == 0L) {
    "No item has display logic that depends on earlier answers."
  } else {
    n <- d$n_conditional
    lim <- sprintf("(limit %s combinations per linked set)", num(d$max_condition_states))
    first <- sprintf("%d %s display logic.", n, pl(n, "item has", "items have"))
    ev <- if (d$n_exact == n) {
      sprintf("%s evaluated for every combination of answers %s.",
              if (n == 1) "It was" else sprintf("All %d were", n), lim)
    } else {
      sprintf("%d %s evaluated for every combination of answers %s.",
              d$n_exact, pl(d$n_exact, "was", "were"), lim)
    }
    ap <- if (d$n_approx == 0L) "None was approximated."
          else sprintf("%d %s approximated.", d$n_approx, pl(d$n_approx, "was", "were"))
    c(first, ev, ap)
  }
  if (isTRUE(d$cross_component_independence)) {
    display <- c(display, sprintf(
      "The %d unlinked sets of display conditions are combined as if independent.",
      d$n_components))
  }
  if (isTRUE(d$n_binary_field_gates > 0L)) {
    display <- c(display, sprintf(
      "%d stored %s used in a test the package cannot evaluate. Each is treated as true or false, and both outcomes are included.",
      d$n_binary_field_gates, pl(d$n_binary_field_gates, "field is", "fields are")))
  }

  # loops
  loops <- if (l$n_known + l$n_unknown == 0L) {
    "There are no Loop & Merge blocks."
  } else {
    out <- character(0)
    if (l$n_known > 0L) {
      b <- sprintf("%s: 0 to %s repetitions.", esc(l$bounds$block_name), l$bounds$max_iter)
      out <- c(out, paste(c(sprintf("%d Loop & Merge %s a fixed maximum.", l$n_known,
                                    pl(l$n_known, "block has", "blocks have")), b),
                          collapse = " "))
    }
    if (l$n_unknown > 0L) {
      out <- c(out, sprintf("%d Loop & Merge %s no fixed maximum.", l$n_unknown,
                            pl(l$n_unknown, "block has", "blocks have")))
    }
    out
  }

  scores <- sprintf("%d %s scored automatically, %d by inference, %d from user input, %d unscored.",
                    s$auto, pl(s$auto, "item", "items"), s$inferred, s$manual, s$unknown)
  list(routes = routes, display = display, loops = loops, scores = scores)
}

print_calculation_certainty_body <- function(x) {
  ln <- certainty_lines(x)

  cli::cli_h1("Calculation certainty: {x$survey_name}")

  cli::cli_h2("Routes")
  for (t in ln$routes) cli::cli_text(t)

  rb <- x$randomisers
  if (!is.null(rb)) rb <- rb[rb$shows_blocks, ]
  if (!is.null(rb) && nrow(rb) > 0) {
    cli::cli_h2("Randomisers")
    for (i in seq_len(nrow(rb))) {
      if (rb$enumerated[i]) {
        cli::cli_text("  {rb$flow_id[i]}: shows {min(rb$subset[i], rb$n_children[i])} of {rb$n_children[i]} elements. Each combination is a separate route.")
      } else {
        cli::cli_text("  {rb$flow_id[i]}: the number shown could not be read. All {rb$n_children[i]} elements are treated as shown.")
      }
    }
  }

  cli::cli_h2("Display logic")
  for (t in ln$display) cli::cli_text(t)

  cli::cli_h2("Loops")
  for (t in ln$loops) cli::cli_text(t)

  cli::cli_h2("Item scores")
  cli::cli_text(ln$scores)

  invisible(x)
}
