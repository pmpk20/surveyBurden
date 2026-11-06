#' Burden by block for each structural traversal of the survey
#'
#' [path_burden_profile()] returns each route's burden distribution as a
#' total. This function returns the traversals behind it: one row per
#' traversal and block, with points, items, response items and pages, so
#' that burden can be accumulated through the survey from the same weighted
#' traversals as the total.
#'
#' A traversal walks a route in flow order. A question is shown if the route
#' always shows it, or if its display logic holds given the answers drawn so
#' far. A trigger question gets a state only when it is shown: hidden means
#' unanswered; shown with a forced response (`ForceResponse = "ON"`, when
#' `respect_force_response = TRUE`) means answered; otherwise answered or
#' unanswered. Each state of a trigger, and each iteration count of a Loop &
#' Merge block (`loop_weights`, equal by default), is a branch. Inside a loop,
#' triggers in the same block are drawn afresh in each iteration; other
#' triggers keep one state.
#'
#' **Weights.** Every route has equal total weight. With `method = "exact"`
#' every branch combination is enumerated and weighted by the product of its
#' branch weights, so the weights reproduce the structural convention of
#' [path_burden_profile()]. With `method = "sample"`, `n_draws` traversals are
#' drawn per route (stratified by route), each with weight
#' `1 / (n_routes * n_draws)`. `"auto"` enumerates when the number of
#' traversals is at most `max_traversals`, and samples otherwise. The method
#' used per route is in `attr(x, "method")`. These are model weights, not
#' observed frequencies.
#'
#' **Derived fields.** `field_rules` derives stored fields from the answers
#' drawn in a traversal, for values that survey code (for example page
#' JavaScript) computes and the survey file does not record. Each element,
#' named by its target (`"@Field"` for a stored field, `"@@n:<BL_id>"` for a
#' loop's iteration count), is a function of the traversal state, or
#' `list(fun = , inputs = )` naming questions the rule reads that are not
#' display-logic triggers (these are then drawn when shown: every choice,
#' plus unanswered unless forced). In the state, a loop question's answer in
#' iteration `j` is `"<QID>#<j>"` and a loop count is `"@@n:<BL_id>"`. A
#' derived field is never enumerated; its value is set before any display
#' logic that reads it. A rule returning `NA` rejects the traversal: exact
#' weights are renormalised within the route, rejected draws are redrawn, and
#' the rejected share per route is in `attr(x, "rejected")`. A loop-count
#' rule requires sampling.
#'
#' **Speed.** A rule is called once per distinct combination of its inputs,
#' and results are reused across chunks and routes. Rules with many inputs
#' (for example an answer in each of ten loop iterations) are faster when
#' vectorised: \code{list(fun = , inputs = , vectorised = TRUE)} calls
#' \code{fun} once per chunk with whole columns (\code{""} for unanswered,
#' choice ids otherwise; loop counts as integers, \code{NULL} when the route
#' has no such loop) and expects one value per traversal.
#'
#' Differences from [path_burden_profile()]: no primary-gate approximation;
#' a conditionally shown forced trigger never has an unanswered state; and
#' `field_rules` apply. Without these, exact traversal quantiles equal the
#' profile's.
#'
#' @inheritParams path_burden_profile
#' @param qsf A `qsf_raw` object or a path accepted by [read_qsf()].
#' @param method `"auto"`, `"exact"` or `"sample"`.
#' @param n_draws Traversals sampled per route.
#' @param seed Random seed for sampling. The global random-number state is
#'   restored afterwards.
#' @param field_rules Optional named list of derivation rules (see Details).
#' @param complete_only Only routes that complete the survey (default).
#' @param max_traversals Largest number of traversals per route that
#'   `"exact"` enumerates.
#' @param output `"long"` (one row per traversal and route block), `"wide"`
#'   (one row per traversal, one points column per survey block) or
#'   `"summary"` (weighted quantiles only; draws are not kept).
#' @param probs Quantile probabilities for `output = "summary"`.
#' @param chunk Draws simulated at a time when sampling.
#'
#' @return For `"long"`, a tibble with `traversal_id`, `path_id`, `weight`,
#'   `block_id`, `flow_order` (the block's position in the survey flow),
#'   `iterations` (`NA` outside loops), `points`, `items`, `response_items`
#'   and `pages`. For `"summary"`, a list with `totals` (weighted quantiles of
#'   the traversal totals of points, response items and pages) and
#'   `cumulative` (weighted quantiles of points accumulated through the
#'   survey's blocks in flow order; blocks a route skips add zero). All
#'   outputs carry attributes `method`, `rejected`, `unresolved`, `seed`,
#'   `n_draws` and `convention`.
#'
#' @examples
#' \donttest{
#' q <- read_qsf(system.file("extdata", "demo_travel_survey.qsf",
#'                           package = "surveyBurden"))
#' x <- path_burden_traversals(q, method = "exact")
#' head(x)
#' }
#' @export
path_burden_traversals <- function(qsf, method = c("auto", "exact", "sample"),
                                   n_draws = 10000L, seed = 1L, loop_weights = NULL,
                                   field_rules = NULL, complete_only = TRUE,
                                   scheme = gfs_scheme(), max_paths = 10000L,
                                   max_traversals = 1e5, overrides = NULL,
                                   choice_tasks = NULL, field_domains = NULL,
                                   respect_force_response = TRUE,
                                   output = c("long", "wide", "summary"),
                                   probs = c(0, .1, .25, .5, .75, .9, 1),
                                   chunk = 10000L) {
  method <- match.arg(method)
  output <- match.arg(output)
  qsf <- if (inherits(qsf, "qsf_raw")) qsf else read_qsf(qsf)
  n_draws <- as.integer(n_draws); chunk <- as.integer(chunk)
  if (is.na(n_draws) || n_draws < 1L) cli::cli_abort("{.arg n_draws} must be a positive whole number.")

  paths  <- resolve_paths(qsf, max_paths = max_paths, field_domains = field_domains)
  scored <- adjust_scores(score_burden(parse_qsf(qsf), scheme = scheme), scheme,
                          choice_tasks, overrides)
  blocks <- resolve_live_blocks(qsf)
  validate_loop_weights(loop_weights, blocks)
  rules  <- normalise_field_rules(field_rules)
  has_n_rule <- any(startsWith(names(rules) %||% character(0), "@@n:"))
  if (has_n_rule && method == "exact") {
    cli::cli_abort(c("A loop-count rule needs {.code method = \"sample\"}.",
                     i = "Loop counts set by a rule are not enumerated."))
  }

  sel <- if (isTRUE(complete_only)) which(!paths$terminates_early) else seq_len(nrow(paths))
  if (!length(sel)) cli::cli_abort("No routes to traverse.")

  ctx <- traversal_context(qsf, scored, blocks, rules, respect_force_response)

  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    old_seed <- get(".Random.seed", envir = globalenv())
    on.exit(assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
  } else {
    on.exit(suppressWarnings(rm(".Random.seed", envir = globalenv())), add = TRUE)
  }
  set.seed(seed)

  n_paths <- length(sel)
  results <- vector("list", n_paths)
  meth <- character(n_paths); rej <- numeric(n_paths)
  unres <- list()
  for (k in seq_along(sel)) {
    i <- sel[k]
    route <- route_spec(ctx, paths, i, loop_weights)
    unres[[k]] <- route$unresolved
    use <- if (method == "auto") (if (has_n_rule) "sample" else "exact") else method
    res <- NULL
    if (use == "exact") {
      res <- tryCatch(walk_route(ctx, route, "exact", 1L, max_traversals),
                      too_many_traversals = function(e) NULL)
      if (is.null(res)) {
        if (method == "exact") {
          cli::cli_abort(c(
            "Path {paths$path_id[i]} has more than {max_traversals} traversals, too many for {.code method = \"exact\"}.",
            i = "Use {.code method = \"sample\"} (or {.code \"auto\"}), or raise {.arg max_traversals}."))
        }
        use <- "sample"
      }
    }
    if (use == "exact") {
      ok <- !res$rej
      if (!any(ok)) cli::cli_abort("Every traversal of path {paths$path_id[i]} was rejected by {.arg field_rules}.")
      rej[k] <- sum(res$w[!ok]) / sum(res$w)
      res <- subset_rows(res, ok)
      res$w <- res$w / sum(res$w) / n_paths
    } else {
      res <- sample_route(ctx, route, n_draws, chunk, paths$path_id[i])
      rej[k] <- res$rejected_share
      res$w <- rep(1 / (n_paths * n_draws), length(res$w))
    }
    meth[k] <- use
    res$path_id <- paths$path_id[i]
    res$bids <- route$bids
    results[[k]] <- if (output == "summary") reduce_summary(res, blocks) else res
  }

  out <- if (output == "summary") combine_summary(results, blocks, probs) else
    assemble_traversals(results, blocks, output)
  attr(out, "method")   <- tibble::tibble(path_id = paths$path_id[sel], method = meth)
  attr(out, "rejected") <- tibble::tibble(path_id = paths$path_id[sel], rejected_share = rej)
  u <- do.call(rbind, unres)
  attr(out, "unresolved") <- tibble::as_tibble(u %||% data.frame(
    path_id = integer(0), question_id = character(0), reason = character(0)))
  attr(out, "seed") <- seed
  attr(out, "n_draws") <- n_draws
  attr(out, "convention") <- paste(
    "Each route has equal total weight; within a route each shown trigger's",
    "states and each loop iteration count (loop_weights, equal by default) are",
    "equally weighted branches; same-block loop triggers are drawn afresh per",
    "iteration. Model weights, not observed frequencies.")
  out
}

#' Monte Carlo stability of sampled traversal quantiles across seeds
#'
#' Reruns [path_burden_traversals()] with `method = "sample"` for each seed
#' and reports the weighted 10th, 50th and 90th percentiles of the traversal
#' totals (GfS+ points), with their range across seeds.
#'
#' @param qsf As in [path_burden_traversals()].
#' @param seeds Seeds to run.
#' @param n_draws Draws per route per seed.
#' @param ... Passed to [path_burden_traversals()].
#' @return A list: `per_seed` (tibble `seed`, `p10`, `median`, `p90`) and
#'   `range` (tibble with rows `min`, `max`, `spread`).
#' @export
traversal_stability <- function(qsf, seeds = 1:5, n_draws = 10000L, ...) {
  rows <- lapply(seeds, function(s) {
    x <- path_burden_traversals(qsf, method = "sample", seed = s, n_draws = n_draws,
                                output = "summary", probs = c(.1, .5, .9), ...)
    p <- x$totals$points
    tibble::tibble(seed = s, p10 = p[1], median = p[2], p90 = p[3])
  })
  per <- do.call(rbind, rows)
  rng <- function(v) c(min(v), max(v), max(v) - min(v))
  list(per_seed = per,
       range = tibble::tibble(stat = c("min", "max", "spread"),
                              p10 = rng(per$p10), median = rng(per$median), p90 = rng(per$p90)))
}

# ---- internals -----------------------------------------------------------------

NA_KEY <- "\001NA"

#' @noRd
normalise_field_rules <- function(field_rules) {
  if (is.null(field_rules)) return(list())
  if (!is.list(field_rules) || is.null(names(field_rules)) || any(names(field_rules) == "")) {
    cli::cli_abort("{.arg field_rules} must be a named list (names are targets such as {.val @Field}).")
  }
  out <- lapply(names(field_rules), function(nm) {
    r <- field_rules[[nm]]
    if (is.function(r)) r <- list(fun = r, inputs = character(0))
    if (!is.list(r) || !is.function(r$fun)) {
      cli::cli_abort("{.arg field_rules} entry {.val {nm}} must be a function or {.code list(fun = , inputs = )}.")
    }
    if (!startsWith(nm, "@")) cli::cli_abort("{.arg field_rules} target {.val {nm}} must start with {.val @}.")
    list(target = nm, fun = r$fun, inputs = as.character(r$inputs %||% character(0)),
         vectorised = isTRUE(r$vectorised))
  })
  stats::setNames(out, names(field_rules))
}

#' Survey-level lookups shared by every route.
#' @noRd
traversal_context <- function(qsf, scored, blocks, rules, respect_force_response) {
  parsed <- parse_all_display_logic(qsf, scored)
  sq <- qsf_elements(qsf, "SQ")
  ids <- vapply(sq, function(p) p$QuestionID %||% NA_character_, character(1))
  choices <- stats::setNames(lapply(sq, function(p) names(p$Choices %||% list())), ids)
  fmap <- force_response_map(qsf)
  flags <- item_flags(scored)
  gfs <- stats::setNames(scored$gfs_points, scored$question_id); gfs[is.na(gfs)] <- 0
  list(
    parsed = parsed, blocks = blocks, rules = rules,
    gfs = gfs,
    stype = stats::setNames(scored$std_type, scored$question_id),
    nopt = stats::setNames(scored$n_options, scored$question_id),
    qblock = stats::setNames(scored$block_id, scored$question_id),
    visible = flags$visible, responsive = flags$responsive,
    page = block_pages(qsf), choices = choices,
    forced = if (isTRUE(respect_force_response)) names(fmap)[fmap] else character(0),
    loop_max = stats::setNames(blocks$loop_max, blocks$block_id),
    memo = new.env(parent = emptyenv())
  )
}

#' What one route needs: blocks, shown sets, triggers and their states.
#' @noRd
route_spec <- function(ctx, paths, i, loop_weights) {
  q_always <- paths$q_always[[i]]; q_maybe <- paths$q_maybe[[i]]
  bids <- paths$block_ids[[i]]
  bids <- bids[bids %in% ctx$blocks$block_id]
  parsed <- ctx$parsed
  cond <- intersect(q_maybe, names(parsed))
  vars <- as.character(unique(unlist(lapply(cond, function(q) parsed[[q]]$vars))))
  targets <- names(ctx$rules) %||% character(0)
  inputs  <- as.character(unique(unlist(lapply(ctx$rules, `[[`, "inputs"))))
  gate_q  <- unique(c(vars[!startsWith(vars, "@")], inputs))
  fields  <- setdiff(vars[startsWith(vars, "@")], c("@@iter", targets))

  loop_bids <- names(ctx$loop_max)[!is.na(ctx$loop_max)]
  loop_q <- names(ctx$qblock)[ctx$qblock %in% loop_bids]
  unres <- list()
  flag <- function(q, why) unres[[length(unres) + 1L]] <<- data.frame(
    path_id = paths$path_id[i], question_id = q, reason = why, stringsAsFactors = FALSE)
  for (q in cond) {
    v <- parsed[[q]]$vars
    own <- ctx$qblock[[q]]
    lv <- v[v %in% loop_q]
    if (own %in% loop_bids) {
      if (any(ctx$qblock[lv] != own)) flag(q, "trigger in another loop")
    } else {
      if (length(lv)) flag(q, "trigger inside a loop")
      if ("@@iter" %in% v) flag(q, "loop position outside loop")
    }
  }

  # state strings per trigger: "" = unanswered / none of the referenced choices
  enc <- function(s) if (is.logical(s)) as.character(s) else if (!length(s)) "" else paste(sort(s), collapse = "+")
  gate_states_str <- function(q) {
    forced <- if (q %in% ctx$forced) q else character(0)
    if (q %in% inputs && identical(ctx$stype[[q]] %||% "", "single_choice")) {
      st <- ctx$choices[[q]] %||% character(0)
      if (!length(forced)) st <- c(st, "")
      return(st)
    }
    vapply(gate_states(q, cond, parsed, ctx$stype, character(0), forced, ctx$nopt), enc, character(1))
  }
  gstates <- stats::setNames(lapply(gate_q, gate_states_str), gate_q)
  fstates <- stats::setNames(lapply(fields, function(v) {
    s <- gate_states(v, cond, parsed, ctx$stype)
    vapply(s, function(x) if (is.logical(x)) as.character(x) else if (is.na(x)) NA_KEY else as.character(x),
           character(1))
  }), fields)
  fkind <- stats::setNames(vapply(fstates, function(s) if (all(s %in% c("TRUE", "FALSE"))) "free" else "field",
                                  character(1)), fields)

  lw <- lapply(bids, function(b) {
    n <- ctx$loop_max[[b]]
    if (is.na(n)) return(NULL)
    w <- loop_weights[[b]] %||% rep(1, n)
    if (is.function(w)) return(w)   # evaluated per row on the loop's shared gates
    w / sum(w)
  })
  names(lw) <- bids
  loop_shared <- lapply(bids, function(b) {
    lc <- intersect(ctx$blocks$question_ids[[match(b, ctx$blocks$block_id)]], cond)
    classify_loop_gates(lc, b, parsed, ctx$qblock)$shared
  })
  names(loop_shared) <- bids

  list(path_id = paths$path_id[i], bids = bids, q_always = q_always, q_maybe = q_maybe,
       route_q = c(q_always, q_maybe), cond = cond, gate_q = gate_q, gstates = gstates,
       fields = fields, fstates = fstates, fkind = fkind, loop_w = lw,
       loop_shared = loop_shared,
       unresolved = if (length(unres)) unique(do.call(rbind, unres)) else NULL)
}

#' Keep a subset of traversal rows.
#' @noRd
subset_rows <- function(res, keep) {
  idx <- if (is.logical(keep)) which(keep) else keep
  res$cols <- lapply(res$cols, function(v) v[idx])
  res$acc  <- lapply(res$acc, function(m) m[idx, , drop = FALSE])
  res$w <- res$w[idx]; res$rej <- res$rej[idx]
  res
}

#' Walk one route for all rows at once. `mode = "exact"` expands rows at each
#' branch; `"sample"` draws one branch per row.
#' @noRd
walk_route <- function(ctx, route, mode, n, max_traversals = Inf) {
  nb <- length(route$bids)
  X <- list(cols = list(), w = rep(1, n), rej = rep(FALSE, n),
            acc = lapply(stats::setNames(nm = c("points", "items", "response_items", "pages", "iterations")),
                         function(.) matrix(0, n, nb)))
  X$acc$iterations[] <- NA_real_
  nrow_x <- function() length(X$w)
  shown0 <- stats::setNames(rep(TRUE, length(route$q_always)), route$q_always)
  parsed <- ctx$parsed

  col <- function(v) {
    x <- X$cols[[v]]
    if (is.null(x)) x <- rep(if (startsWith(v, "@") && !startsWith(v, "@@")) NA_KEY else "", nrow_x())
    x
  }
  branch <- function(name, rows, states, prob = NULL) {
    if (!is.null(prob)) {   # zero-weight branches are not traversals
      keep_b <- prob > 0; states <- states[keep_b]; prob <- prob[keep_b] / sum(prob[keep_b])
    }
    k <- length(states)
    if (!any(rows)) return(invisible())
    if (k == 1L) { v <- col(name); v[rows] <- states; X$cols[[name]] <<- v; return(invisible()) }
    if (mode == "sample") {
      v <- col(name)
      v[rows] <- states[sample.int(k, sum(rows), replace = TRUE, prob = prob)]
      X$cols[[name]] <<- v
      return(invisible())
    }
    keep <- which(!rows); grow <- which(rows)
    idx <- c(keep, rep(grow, each = k))
    if (length(idx) > max_traversals) {
      stop(structure(class = c("too_many_traversals", "error", "condition"),
                     list(message = "too many traversals", call = NULL)))
    }
    pw <- if (is.null(prob)) rep(1 / k, k) else prob
    X$cols <<- lapply(X$cols, function(v) v[idx])
    X$acc  <<- lapply(X$acc, function(m) m[idx, , drop = FALSE])
    X$w    <<- X$w[idx] * c(rep(1, length(keep)), rep(pw, times = length(grow)))
    X$rej  <<- X$rej[idx]
    v <- col(name)
    v[length(keep) + seq_len(length(grow) * k)] <- rep(states, times = length(grow))
    X$cols[[name]] <<- v
    invisible()
  }
  decode <- function(v, val) {
    if (v == "@@iter" || startsWith(v, "@@n:")) return(as.integer(val))
    if (startsWith(v, "@")) {
      if (v %in% names(route$fkind) && identical(route$fkind[[v]], "free")) return(as.logical(val))
      return(if (identical(val, NA_KEY)) NA_character_ else val)
    }
    if (identical(val, "")) character(0) else strsplit(val, "+", fixed = TRUE)[[1]]
  }
  # evaluate f(state) once per distinct combination of the columns it reads
  # Returns list(res, m, idx): one result per distinct combination (`res`),
  # and for the rows `idx` the index `m` of their combination in `res`.
  by_key <- function(vars, rows, f, memo = NULL) {
    idx <- which(rows)
    if (!length(idx)) return(list(res = list(), m = integer(0), idx = idx))
    vals <- lapply(vars, function(v) col(v)[idx])
    key <- if (length(vars)) do.call(paste, c(vals, sep = "\r")) else rep("", length(idx))
    u <- unique(key); m <- match(key, u)
    first <- match(seq_along(u), m)
    eval_one <- function(r) {
      st <- stats::setNames(lapply(seq_along(vars), function(j) decode(vars[j], vals[[j]][r])), vars)
      f(st)
    }
    if (is.null(memo)) return(list(res = lapply(first, eval_one), m = m, idx = idx))
    ku <- paste0("k", u)
    res <- mget(ku, envir = memo, ifnotfound = list(NULL))
    miss <- which(vapply(res, is.null, logical(1)))
    if (length(miss)) {
      new <- lapply(first[miss], eval_one)
      res[miss] <- new
      list2env(stats::setNames(new, ku[miss]), envir = memo)
    }
    list(res = unname(res), m = m, idx = idx)
  }
  memo_for <- function(kind, name) {
    nm <- paste0(kind, ":", name)
    e <- ctx$memo[[nm]]
    if (is.null(e)) { e <- new.env(parent = emptyenv()); assign(nm, e, envir = ctx$memo) }
    e
  }
  apply_rule <- function(rule, rows) {
    cols <- if (length(rule$inputs)) {
      unlist(lapply(rule$inputs, function(q) {
        b <- ctx$qblock[[q]] %||% NA_character_
        mx <- if (!is.na(b)) ctx$loop_max[[b]] else NA
        if (!is.na(mx)) c(q, paste0(q, "#", seq_len(mx))) else q
      }))
    } else {
      intersect(names(X$cols), c(route$gate_q, route$fields))
    }
    cols <- unique(c(cols, grep("^@@n:", names(X$cols), value = TRUE)))
    # recompute only rows whose inputs changed since the last evaluation
    key_col <- paste0(".rk:", rule$target)
    key <- if (length(cols)) do.call(paste, c(lapply(cols, col), sep = "\r")) else rep("", nrow_x())
    old <- X$cols[[key_col]]
    todo <- rows & (is.null(old) | (if (is.null(old)) TRUE else old != key))
    if (any(todo) && isTRUE(rule$vectorised)) {
      ti <- which(todo)
      sv <- stats::setNames(lapply(cols, function(cn) {
        x <- col(cn)[ti]
        if (startsWith(cn, "@@n:")) suppressWarnings(as.integer(x)) else x
      }), cols)
      sv <- structure(sv, class = "rule_state", rule = rule$target)
      out <- tryCatch(rule$fun(sv), rule_state_unknown = function(e) stop(e),
                      error = function(e) cli::cli_abort(
        "{.arg field_rules} entry {.val {rule$target}} failed: {conditionMessage(e)}"))
      if (length(out) != length(ti)) {
        cli::cli_abort("{.arg field_rules} entry {.val {rule$target}} (vectorised) returned {length(out)} value{?s} for {length(ti)} traversal{?s}.")
      }
      enc <- ifelse(is.na(out), NA_KEY, as.character(out))
      v <- col(rule$target); v[ti] <- enc; X$cols[[rule$target]] <<- v
    } else if (any(todo)) {
      vals <- by_key(cols, todo, function(st) {
        st <- structure(st, class = "rule_state", rule = rule$target)
        v <- tryCatch(rule$fun(st), rule_state_unknown = function(e) stop(e),
                      error = function(e) cli::cli_abort(
          "{.arg field_rules} entry {.val {rule$target}} failed: {conditionMessage(e)}"))
        if (length(v) != 1L || is.na(v)) NA_KEY else as.character(v)
      }, memo = memo_for("rule", paste(rule$target, paste(cols, collapse = ","))))
      v <- col(rule$target)
      v[vals$idx] <- unlist(vals$res)[vals$m]
      X$cols[[rule$target]] <<- v
      kc <- if (is.null(old)) rep(NA_character_, nrow_x()) else old
      kc[todo] <- key[todo]
      X$cols[[key_col]] <<- kc
    }
  }
  shown_of <- function(q, rows, j) {
    if (!q %in% route$route_q) return(rep(FALSE, nrow_x()))
    if (q %in% route$q_always || is.null(parsed[[q]])) return(rows)
    vars <- parsed[[q]]$vars
    for (t in intersect(vars, names(ctx$rules))) apply_rule(ctx$rules[[t]], rows)
    if (!is.na(j)) { X$cols[["@@iter"]] <<- rep(as.character(j), nrow_x()) }
    else X$cols[["@@iter"]] <<- NULL
    pred <- parsed[[q]]$predicate
    mk <- if (length(parsed[[q]]$displayed)) paste(q, route$path_id) else q
    r <- by_key(c(vars, if (!is.na(j)) "@@iter"), rows,
                function(st) isTRUE(pred(st, shown0)), memo = memo_for("pred", mk))
    s <- rows
    if (length(r$idx)) s[r$idx] <- vapply(r$res, isTRUE, logical(1))[r$m]
    s
  }
  visit <- function(q, k, j, ncol_name) {
    in_loop <- !is.na(j)
    rows <- if (in_loop) X$cols[[".ni"]] >= j else rep(TRUE, nrow_x())
    s <- shown_of(q, rows, j)
    pts <- ctx$gfs[[q]] %||% 0
    vis <- isTRUE(ctx$visible[[q]]); resp <- isTRUE(ctx$responsive[[q]])
    X$acc$points[s, k]         <<- X$acc$points[s, k] + pts
    X$acc$items[s, k]          <<- X$acc$items[s, k] + vis
    X$acc$response_items[s, k] <<- X$acc$response_items[s, k] + (vis && resp)
    if (vis) {
      pg <- paste0(".pg:", ctx$page[[q]] %||% "1")
      v <- X$cols[[pg]] %||% rep(FALSE, nrow_x())
      v[s] <- TRUE
      X$cols[[pg]] <<- v
    }
    if (q %in% route$gate_q) {
      hid <- rows & !s
      v <- col(q); v[hid] <- ""; X$cols[[q]] <<- v
      jn <- if (in_loop) paste0(q, "#", j) else NULL
      if (in_loop) { v <- col(jn); v[hid] <- ""; X$cols[[jn]] <<- v }
      # mark the shown rows: exact branching replicates and reorders rows
      X$cols[[".shown"]] <<- s
      branch(q, s, route$gstates[[q]])
      if (in_loop) {
        s2 <- X$cols[[".shown"]]; v <- col(jn); v[s2] <- col(q)[s2]; X$cols[[jn]] <<- v
      }
      X$cols[[".shown"]] <<- NULL
    }
  }
  close_pages <- function(k, rows) {
    pcols <- grep("^\\.pg:", names(X$cols), value = TRUE)
    if (length(pcols)) {
      hits <- Reduce(`+`, lapply(pcols, function(p) as.integer(X$cols[[p]])))
      X$acc$pages[rows, k] <<- X$acc$pages[rows, k] + hits[rows]
      for (p in pcols) X$cols[[p]] <<- NULL
    }
  }

  # stored fields and free gates: one state per traversal, drawn at the start
  for (f in route$fields) branch(f, rep(TRUE, nrow_x()), route$fstates[[f]])

  for (k in seq_along(route$bids)) {
    b <- route$bids[k]
    qs <- ctx$blocks$question_ids[[match(b, ctx$blocks$block_id)]]
    mx <- ctx$loop_max[[b]]
    if (is.na(mx)) {
      for (q in qs) visit(q, k, NA_integer_, NULL)
      close_pages(k, rep(TRUE, nrow_x()))
      next
    }
    ncol_name <- paste0("@@n:", b)
    nrule <- ctx$rules[[ncol_name]]
    if (!is.null(nrule)) {
      apply_rule(nrule, rep(TRUE, nrow_x()))
      v <- suppressWarnings(as.integer(X$cols[[ncol_name]]))
      v[is.na(v)] <- 0L
      X$cols[[ncol_name]] <- as.character(pmin(pmax(v, 0L), mx))
    } else if (is.function(route$loop_w[[b]])) {
      fw <- route$loop_w[[b]]; sh <- route$loop_shared[[b]]
      wv <- by_key(sh, rep(TRUE, nrow_x()), function(st) check_loop_weight_vector(fw(st), b, mx))
      wk <- vapply(wv$res, function(x) paste(x, collapse = "/"), character(1))[wv$m]
      X$cols[[".wkey"]] <- wk
      for (wkey in unique(wk)) {
        w1 <- as.numeric(strsplit(wkey, "/", fixed = TRUE)[[1]])
        rows <- X$cols[[".wkey"]] == wkey & col(ncol_name) == ""
        branch(ncol_name, rows, as.character(seq_len(mx)), w1 / sum(w1))
      }
      X$cols[[".wkey"]] <- NULL
    } else {
      branch(ncol_name, rep(TRUE, nrow_x()), as.character(seq_len(mx)), route$loop_w[[b]])
    }
    X$cols[[".ni"]] <- as.integer(col(ncol_name))   # replicated with the rows
    for (q in intersect(qs, route$gate_q)) for (j in seq_len(mx)) {
      X$cols[[paste0(q, "#", j)]] <- rep("", nrow_x())
    }
    for (j in seq_len(mx)) {
      act <- X$cols[[".ni"]] >= j
      if (!any(act)) break
      for (q in intersect(qs, route$gate_q)) { v <- col(q); v[act] <- ""; X$cols[[q]] <- v }
      for (q in qs) visit(q, k, j, ncol_name)
      act <- X$cols[[".ni"]] >= j
      close_pages(k, act)
    }
    X$acc$iterations[, k] <- as.numeric(X$cols[[".ni"]])
    X$cols[[".ni"]] <- NULL
  }
  X$cols[["@@iter"]] <- NULL
  for (r in ctx$rules) if (!startsWith(r$target, "@@n:")) {
    apply_rule(r, rep(TRUE, nrow_x()))
    X$rej <- X$rej | col(r$target) == NA_KEY
  }
  for (k in grep("^\\.rk:", names(X$cols), value = TRUE)) X$cols[[k]] <- NULL
  X
}

#' Sample `n_draws` accepted traversals of one route, in chunks; rejected
#' draws are redrawn.
#' @noRd
sample_route <- function(ctx, route, n_draws, chunk, path_id) {
  got <- list(); accepted <- 0L; drawn <- 0L
  cap <- 100 * n_draws
  while (accepted < n_draws) {
    if (drawn >= cap) {
      if (accepted == 0L) {
        cli::cli_abort("Every traversal of path {path_id} was rejected by {.arg field_rules}.")
      }
      cli::cli_abort("Path {path_id}: {.arg field_rules} rejected too many draws ({drawn - accepted} of {drawn}).")
    }
    m <- min(chunk, max(n_draws - accepted, 1L) * if (drawn == 0L) 1L else 2L, chunk)
    r <- walk_route(ctx, route, "sample", m)
    drawn <- drawn + m
    ok <- !r$rej
    if (any(ok)) { got[[length(got) + 1L]] <- subset_rows(r, ok); accepted <- accepted + sum(ok) }
  }
  acc <- lapply(stats::setNames(nm = names(got[[1]]$acc)), function(a)
    do.call(rbind, lapply(got, function(g) g$acc[[a]]))[seq_len(n_draws), , drop = FALSE])
  list(acc = acc, w = rep(1, n_draws), rej = rep(FALSE, n_draws), cols = list(),
       rejected_share = (drawn - accepted) / drawn)
}

#' Survey flow order of a route's blocks.
#' @noRd
route_flow_order <- function(bids, blocks) blocks$flow_order[match(bids, blocks$block_id)]

#' Long or wide traversal table.
#' @noRd
assemble_traversals <- function(results, blocks, output) {
  offset <- 0L
  parts <- lapply(results, function(r) {
    nt <- length(r$w); nb <- length(r$bids)
    ids <- offset + seq_len(nt); offset <<- offset + nt
    fo <- route_flow_order(r$bids, blocks)
    if (output == "long") {
      return(tibble::tibble(
        traversal_id = rep(ids, times = nb), path_id = r$path_id,
        weight = rep(r$w, times = nb), block_id = rep(r$bids, each = nt),
        flow_order = rep(fo, each = nt),
        iterations = as.integer(c(r$acc$iterations)),
        points = c(r$acc$points), items = as.integer(c(r$acc$items)),
        response_items = as.integer(c(r$acc$response_items)),
        pages = as.integer(c(r$acc$pages))))
    }
    pts <- matrix(0, nt, nrow(blocks), dimnames = list(NULL, blocks$block_id))
    pts[, r$bids] <- r$acc$points
    tibble::as_tibble(data.frame(
      traversal_id = ids, path_id = r$path_id, weight = r$w,
      pts, points = rowSums(r$acc$points), items = rowSums(r$acc$items),
      response_items = rowSums(r$acc$response_items), pages = rowSums(r$acc$pages),
      check.names = FALSE))
  })
  out <- do.call(rbind, parts)
  if (output == "long") out <- out[order(out$traversal_id, out$flow_order), ]
  out
}

#' Reduce one route's traversals to weight tables (totals, and cumulative
#' points after each survey block, skipped blocks adding zero).
#' @noRd
reduce_summary <- function(r, blocks) {
  fo <- route_flow_order(r$bids, blocks)
  o  <- order(fo)
  pm <- r$acc$points[, o, drop = FALSE]; fo <- fo[o]
  cum <- if (ncol(pm) > 1L) t(apply(pm, 1L, cumsum)) else pm
  if (nrow(pm) == 1L && ncol(pm) > 1L) cum <- matrix(cum, nrow = 1L)
  cum_tabs <- lapply(blocks$flow_order, function(f) {
    j <- max(c(0L, which(fo <= f)))
    group_sum(if (j == 0L) rep(0, nrow(pm)) else cum[, j], r$w)
  })
  list(points = group_sum(rowSums(r$acc$points), r$w),
       response_items = group_sum(rowSums(r$acc$response_items), r$w),
       pages = group_sum(rowSums(r$acc$pages), r$w),
       cumulative = cum_tabs)
}

#' Combine per-route weight tables into weighted quantiles.
#' @noRd
combine_summary <- function(tabs, blocks, probs) {
  q_of <- function(lst) {
    d <- group_sum(unlist(lapply(lst, `[[`, "burden")), unlist(lapply(lst, `[[`, "weight")))
    weighted_quantile(d$burden, d$weight, probs)
  }
  totals <- tibble::tibble(
    prob = probs,
    points = q_of(lapply(tabs, `[[`, "points")),
    response_items = q_of(lapply(tabs, `[[`, "response_items")),
    pages = q_of(lapply(tabs, `[[`, "pages")))
  cumulative <- do.call(rbind, lapply(seq_len(nrow(blocks)), function(b) {
    tibble::tibble(flow_order = blocks$flow_order[b], block_id = blocks$block_id[b],
                   prob = probs, points = q_of(lapply(tabs, function(t) t$cumulative[[b]])))
  }))
  list(totals = totals, cumulative = cumulative)
}

#' Strict access to a rule's traversal state: reading a name the rule did not
#' declare (and that is not a loop count) is an error naming the rule.
#' @param x A traversal state passed to a `field_rules` function.
#' @param i Name to read.
#' @param ... Unused.
#' @keywords internal
#' @export
`[[.rule_state` <- function(x, i, ...) {
  nm <- names(unclass(x))
  if (i %in% nm) return(unclass(x)[[i]])
  if (startsWith(i, "@@n:")) return(NULL)
  rule <- attr(x, "rule")
  cli::cli_abort(c(
    "{.arg field_rules} entry {.val {rule}} read {.val {i}}, which it did not declare.",
    i = "Add it to the rule's {.code inputs}, e.g. {.code list(fun = , inputs = c(\"{i}\"))}."),
    class = "rule_state_unknown")
}

#' @rdname sub-.rule_state
#' @export
`$.rule_state` <- function(x, name) x[[name]]
