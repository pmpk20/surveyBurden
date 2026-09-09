#' Burden per respondent path
#'
#' Joins [resolve_paths()] to [score_burden()] and reports, for every flow path,
#' a burden band: the *floor* (only always-shown questions, loop blocks run once)
#' and the *ceiling* (every reachable question, loop blocks run to their maximum).
#' The true burden of any actual respondent on that path lies between.
#'
#' @param qsf A `qsf_raw` object from [read_qsf()].
#' @param weights A [gfs_weights()] list.
#' @param max_paths Passed to [resolve_paths()].
#' @param paths,scored Optional precomputed [resolve_paths()] and
#'   [score_burden()] results for this `qsf` (internal reuse; `NULL` computes
#'   them here, leaving the public behaviour unchanged).
#'
#' @return A [tibble][tibble::tibble], one row per flow path:
#'   `path_id`, `terminates_early`, `n_blocks`, `n_q_floor`, `n_q_ceiling`,
#'   `gfs_floor`, `gfs_ceiling`, `min_minutes`, `max_minutes`, `n_gates`.
#'
#' @export
path_burden <- function(qsf, weights = gfs_weights(), max_paths = 10000L,
                        paths = NULL, scored = NULL) {
  if (is.null(paths))  paths  <- resolve_paths(qsf, max_paths = max_paths)
  if (is.null(scored)) scored <- score_burden(parse_qsf(qsf), weights = weights)

  pts  <- stats::setNames(scored$gfs_points, scored$question_id)
  lmax <- stats::setNames(scored$loop_max, scored$question_id)
  ppm  <- weights$points_per_minute

  band <- function(q_always, q_maybe) {
    floor_q   <- q_always
    ceiling_q <- c(q_always, q_maybe)

    gfs_floor <- sum(pts[floor_q] * loop_mult(floor_q, lmax, cap = FALSE), na.rm = TRUE)
    gfs_ceil  <- sum(pts[ceiling_q] * loop_mult(ceiling_q, lmax, cap = TRUE), na.rm = TRUE)
    c(gfs_floor, gfs_ceil, length(floor_q), length(ceiling_q))
  }

  rows <- Map(band, paths$q_always, paths$q_maybe)
  m <- do.call(rbind, rows)

  tibble::tibble(
    path_id          = paths$path_id,
    terminates_early = paths$terminates_early,
    n_blocks         = lengths(paths$block_ids),
    n_q_floor        = as.integer(m[, 3]),
    n_q_ceiling      = as.integer(m[, 4]),
    gfs_floor        = m[, 1],
    gfs_ceiling      = m[, 2],
    min_minutes      = m[, 1] / ppm,
    max_minutes      = m[, 2] / ppm,
    n_gates          = paths$n_gates
  )
}

#' Per-question loop multiplier: 1 outside a loop; 1 (floor) or loop_max (ceiling)
#' inside one.
#' @noRd
loop_mult <- function(qids, lmax, cap) {
  m <- lmax[qids]
  out <- rep(1, length(qids))
  in_loop <- !is.na(m)
  if (cap) out[in_loop] <- m[in_loop]
  out
}
