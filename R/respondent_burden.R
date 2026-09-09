#' Expected burden by respondent route
#'
#' Turns the flow/display-logic model into a per-route expected burden, so you
#' can say "a typical respondent faces ~X points, rising to ~Y once the Loop &
#' Merge sections repeat, or ~Z on the shortest complete route".
#'
#' @param qsf A `qsf_raw` object or a path/URL accepted by [read_qsf()].
#' @param routes Optional data frame of respondents. Recognised columns (all
#'   optional):
#'   \describe{
#'     \item{`loop_<id>`}{Iteration count for a Loop & Merge block. `<id>` may be
#'       the driving question id (`loop_QID9`) or the block id (`loop_BL6`). Any
#'       other `loop_*` column is assigned to the survey's loop blocks in flow
#'       order. `0` means the respondent never entered that loop; a missing
#'       column falls back to `loop_typical`.}
#'     \item{`visit_<block_id>`}{`TRUE` to include a branch-gated optional block
#'       (e.g. `visit_BL11`). Absent or `FALSE` excludes it.}
#'   }
#'   Missing columns are treated as absent/zero.
#' @param weights A [gfs_weights()] list.
#' @param loop_typical Loop iterations to assume for the `typical_pts` column,
#'   and for a route whose loop count is not supplied.
#' @param engine Optional precomputed `burden_engine()` result for this `qsf`
#'   (internal reuse by [burden_report()]; `NULL` builds it here, leaving the
#'   public behaviour unchanged).
#'
#' @return
#'   If `routes` is `NULL`: a `respondent_burden` tibble, one row per complete
#'   flow path, with `path_id`, `n_loop_blocks`, `optional_blocks` (a list column
#'   of branch-gated block ids on that path) and `floor_pts` / `typical_pts` /
#'   `ceiling_pts` (+ `_min` in minutes). [summary_line()] turns it into a
#'   sentence.
#'
#'   If `routes` is supplied: the routes tibble with `path_id`, `matched`
#'   (`TRUE` if the respondent's branch signature matched one of the enumerated
#'   complete flow paths; `FALSE` falls back to the heaviest path and warns --
#'   a route-recovery diagnostic on the flow model itself), `pred_pts` and
#'   `pred_min` (predicted burden using each respondent's real loop counts).
#'
#' @export
respondent_burden <- function(qsf, routes = NULL, weights = gfs_weights(),
                              loop_typical = 2, engine = NULL) {
  if (!inherits(qsf, "qsf_raw")) qsf <- read_qsf(qsf)
  e   <- engine %||% burden_engine(qsf, weights = weights)
  ppm <- weights$points_per_minute
  full_i <- which(!e$paths$terminates_early)
  if (length(full_i) == 0L) {
    cli::cli_abort("No complete flow paths: every enumerated path terminates early.")
  }

  # loop block -> driving question id, straight from the flow model
  loop_qid <- stats::setNames(e$blocks$loop_on_qid, e$blocks$block_id)
  loop_qid <- loop_qid[!is.na(loop_qid)]
  loop_order <- e$blocks$block_id[!is.na(e$blocks$loop_on_qid)]  # flow order

  # branch-gated blocks: any block not present on every complete path
  full_block_sets <- e$paths$block_ids[full_i]
  common_blocks   <- Reduce(intersect, full_block_sets)
  optional_blocks <- setdiff(unique(unlist(full_block_sets)), common_blocks)

  info <- lapply(seq_along(full_i), function(k) {
    i  <- full_i[k]
    cp <- e$components[[i]]
    b  <- e$paths$block_ids[[i]]
    dsum <- weighted_quantile(cp$display_dist$burden, cp$display_dist$weight, c(0, .5, 1))
    loops <- lapply(names(cp$loops), function(bid) list(
      block_id = bid,
      qid      = unname(loop_qid[bid]),
      per_iter = cp$loops[[bid]]$per_iter,
      n        = cp$loops[[bid]]$n
    ))
    list(
      path_id    = e$paths$path_id[i],
      opt_blocks = intersect(b, optional_blocks),
      base = cp$base, disp = dsum, loops = loops
    )
  })

  if (is.null(routes)) {
    tab <- do.call(rbind, lapply(info, function(x) {
      lp <- function(mult_fn) sum(vapply(x$loops,
        function(l) l$per_iter * mult_fn(l), numeric(1)))
      tibble::tibble(
        path_id        = x$path_id,
        n_loop_blocks  = length(x$loops),
        optional_blocks = list(x$opt_blocks),
        floor_pts   = x$base + x$disp[1] + lp(function(l) 1),
        typical_pts = x$base + x$disp[2] + lp(function(l) min(loop_typical, l$n)),
        ceiling_pts = x$base + x$disp[3] + lp(function(l) l$n)
      )
    }))
    tab$floor_min   <- tab$floor_pts / ppm
    tab$typical_min <- tab$typical_pts / ppm
    tab$ceiling_min <- tab$ceiling_pts / ppm
    attr(tab, "ppm") <- ppm
    class(tab) <- c("respondent_burden", class(tab))
    return(tab)
  }

  # ---- per-respondent prediction --------------------------------------------
  n_r <- nrow(routes)

  # resolve each loop block to a route column of iteration counts
  loop_cols <- grep("^loop_", names(routes), value = TRUE)
  generic_pool <- setdiff(
    loop_cols,
    c(paste0("loop_", loop_qid), paste0("loop_", loop_order))
  )
  loop_count_for <- function(bid, qid) {
    for (nm in c(paste0("loop_", qid), paste0("loop_", bid))) {
      if (nm %in% names(routes)) return(as.numeric(routes[[nm]]))
    }
    pos <- match(bid, loop_order)
    if (!is.na(pos) && pos <= length(generic_pool)) {
      return(as.numeric(routes[[generic_pool[pos]]]))
    }
    rep(NA_real_, n_r)
  }
  loop_counts <- stats::setNames(
    lapply(loop_order, function(bid) loop_count_for(bid, unname(loop_qid[bid]))),
    loop_order
  )

  # desired optional-block set per respondent, from visit_<bid> columns
  desired_opt <- lapply(seq_len(n_r), function(r) {
    keep <- vapply(optional_blocks, function(bid) {
      col <- paste0("visit_", bid)
      !is.null(routes[[col]]) && isTRUE(as.logical(routes[[col]][r]))
    }, logical(1))
    optional_blocks[keep]
  })

  sig_of  <- function(v) paste(sort(unique(v)), collapse = "|")
  path_sig <- vapply(info, function(x) sig_of(x$opt_blocks), character(1))
  plain_i  <- which(path_sig == "")
  heavy_i  <- which.max(vapply(info, function(x) x$base + x$disp[3], numeric(1)))

  idx     <- integer(n_r)
  matched <- logical(n_r)
  for (r in seq_len(n_r)) {
    hit <- which(path_sig == sig_of(desired_opt[[r]]))
    if (length(hit)) {
      idx[r] <- hit[1]; matched[r] <- TRUE
    } else if (length(plain_i)) {
      idx[r] <- plain_i[1]; matched[r] <- TRUE
    } else {
      idx[r] <- heavy_i; matched[r] <- FALSE
    }
  }

  pred <- vapply(seq_len(n_r), function(r) {
    x <- info[[idx[r]]]
    lp <- sum(vapply(x$loops, function(l) {
      cnt <- loop_counts[[l$block_id]][r]
      if (is.na(cnt)) cnt <- loop_typical
      mult <- if (cnt <= 0) 0 else min(cnt, l$n)
      l$per_iter * mult
    }, numeric(1)))
    x$base + x$disp[2] + lp
  }, numeric(1))

  out <- tibble::as_tibble(routes)
  out$path_id  <- vapply(idx, function(j) info[[j]]$path_id, e$paths$path_id[1])
  out$matched  <- matched
  out$pred_pts <- pred
  out$pred_min <- pred / ppm
  if (!all(matched)) {
    cli::cli_warn(
      "{sum(!matched)} of {length(matched)} respondent route(s) did not match any of the {length(full_i)} enumerated complete flow paths ({.field matched} = FALSE); their prediction fell back to the heaviest path. This flags either an incomplete flow model or a route-encoding mismatch."
    )
  }
  out
}

#' One-sentence summary of a burden object
#'
#' @param x A [respondent_burden()] table (the no-routes form).
#' @param ... Unused.
#' @return A single character string.
#' @export
summary_line <- function(x, ...) UseMethod("summary_line")

#' @export
summary_line.respondent_burden <- function(x, ...) {
  ppm <- attr(x, "ppm") %||% 12
  med <- stats::median(x$typical_pts)
  lo  <- min(x$typical_pts)
  hi  <- max(x$ceiling_pts)
  sprintf(
    paste0("Typical respondent burden is about %.0f GfS points (~%.0f min). ",
           "The lightest complete route is ~%.0f pts (~%.0f min); with the Loop ",
           "& Merge sections fully repeated it reaches ~%.0f pts (~%.0f min)."),
    med, med / ppm, lo, lo / ppm, hi, hi / ppm
  )
}

#' @export
print.respondent_burden <- function(x, ...) {
  if (all(c("typical_pts") %in% names(x)) && !is.null(attr(x, "ppm"))) {
    cli::cli_text(summary_line(x))
    cli::cli_text("")
  }
  NextMethod()
}
