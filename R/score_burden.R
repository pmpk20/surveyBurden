#' Score per-question burden
#'
#' Applies the GfS+ scoring rules (extending Heimgartner and Axhausen 2024,
#' \doi{10.32866/001c.125481}) via [gfs_scheme()] to a question catalogue
#' from [parse_qsf()], adding burden points, an estimated completion time,
#' a confidence flag and a plain-language rationale per item.
#' This is Layer 3 at the item level; propagation through the survey's paths is a
#' later step.
#'
#' The published GfS Table 1 point values are applied directly where the
#' required structure can be read from the QSF. Where the QSF does not contain
#' the quantity GfS needs -- a dropdown has no Table 1 row, a slider is not in
#' the scheme, "lines" of text are not in a QSF -- the package applies an
#' explicit, documented inference rule. `score_flag` and `score_basis` say
#' which case each item is.
#'
#' With `scheme$apply_filter_branching = TRUE`, a question whose answer drives
#' display logic or a flow branch also gains the GfS `filter` / `branching`
#' points (see [gfs_scheme()]), flagged at least `"inferred"`.
#'
#' @param catalogue A tibble from [parse_qsf()].
#' @param scheme A named list of scheme; defaults to [gfs_scheme()].
#'
#' @return `catalogue` with four columns added:
#'   \describe{
#'     \item{`gfs_points`}{Estimated GfS burden points (`NA` if the item cannot
#'       be scored -- an unrecognised type).}
#'     \item{`est_seconds`}{`gfs_points` converted at `points_per_minute`.}
#'     \item{`score_flag`}{`"auto"` (the GfS mapping is deterministic from the
#'       structure), `"inferred"` (the structure is clear but the mapping onto
#'       a GfS category involved an explicit, documented judgement -- the number
#'       is still determinate), `"manual"` (a human should check) or
#'       `"unknown"` (unmapped type).}
#'     \item{`score_basis`}{A short human-readable statement of how the number
#'       was reached.}
#'   }
#'
#' @examples
#' qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
#'                          package = "surveyBurden")
#' scored <- score_burden(parse_qsf(qsf_path))
#' scored[, c("question_id", "std_type", "gfs_points", "score_flag")]
#'
#' @export
score_burden <- function(catalogue, scheme = gfs_scheme()) {
  catalogue <- validate_catalogue(catalogue)

  cols <- as.list(catalogue)
  rows <- lapply(seq_len(nrow(catalogue)),
                 function(i) lapply(cols, function(col) col[[i]]))
  scored <- lapply(rows, score_item, scheme)

  gfs   <- vapply(scored, `[[`, numeric(1), "gfs_points")
  flag  <- vapply(scored, `[[`, character(1), "score_flag")
  basis <- vapply(scored, `[[`, character(1), "score_basis")

  if (isTRUE(scheme$apply_filter_branching)) {
    # GfS filter / branching: 0.5 per role on the answered question whose
    # answer drives display logic or a flow branch.
    f <- catalogue$filter_trigger %in% TRUE
    b <- catalogue$branch_trigger %in% TRUE
    hit <- (f | b) & !is.na(gfs) & !(catalogue$is_hidden %in% TRUE) &
      !catalogue$std_type %in% c("descriptive", "timing", "meta", "captcha")
    gfs[hit] <- gfs[hit] + scheme$filter * f[hit] + scheme$branching * b[hit]
    role <- ifelse(f & b, sprintf("GfS filter %.1f + branching %.1f", scheme$filter, scheme$branching),
                   ifelse(f, sprintf("GfS filter %.1f", scheme$filter),
                          sprintf("GfS branching %.1f", scheme$branching)))
    basis[hit] <- paste0(basis[hit], "; + ", role[hit],
                         " (its answer drives later routing)")
    flag[hit] <- vapply(flag[hit], escalate, character(1), to = "inferred")
  }

  catalogue$gfs_points  <- gfs
  catalogue$est_seconds <- gfs / scheme$points_per_minute * 60
  catalogue$score_flag  <- flag
  catalogue$score_basis <- basis
  catalogue
}

#' Apply user score overrides to a [score_burden()] table: a named numeric
#' vector of points keyed by question id. Overridden items get
#' `score_flag = "manual"` and `score_basis = "user override"`. `NULL` returns
#' `scored` unchanged. `est_seconds` is recomputed at the scheme's points per
#' minute.
#' @noRd
score_overrides <- function(scored, overrides, scheme = gfs_scheme()) {
  if (is.null(overrides)) return(scored)
  if (!is.numeric(overrides)) {
    cli::cli_abort("{.arg overrides} must be a named numeric vector of points, e.g. {.code c(QID51 = 10)}.")
  }
  ids <- names(overrides)
  if (is.null(ids) || anyNA(ids) || any(ids == "")) {
    cli::cli_abort("Every element of {.arg overrides} must be named with a question id, e.g. {.code c(QID51 = 10)}.")
  }
  dup <- unique(ids[duplicated(ids)])
  if (length(dup)) {
    cli::cli_abort("{.arg overrides} names {cli::qty(length(dup))}question{?s} more than once: {.val {dup}}.")
  }
  if (anyNA(overrides) || any(!is.finite(overrides)) || any(overrides < 0)) {
    cli::cli_abort("{.arg overrides} must be finite, non-negative numbers of points.")
  }
  unknown <- setdiff(ids, scored$question_id)
  if (length(unknown)) {
    cli::cli_abort(c(
      "{.arg overrides} names {cli::qty(length(unknown))}question{?s} not in this survey: {.val {unknown}}.",
      i = "Use the ids in {.code score_burden()$question_id} (or {.code burden_report()$items})."
    ))
  }
  set_item_scores(scored, match(ids, scored$question_id),
                  unname(as.numeric(overrides)), "user override", scheme)
}

#' Score declared stated-choice tasks by the GfS stated-choice rows:
#' `sc_2_alt` or `sc_3_alt` for the alternatives (`sc_per_extra_alt` for each
#' beyond three, an extrapolation past GfS Table 1) plus `sc_per_variable` per
#' attribute. `choice_tasks` is a data frame with `question_id`,
#' `n_alternatives` and `n_attributes`. Scored items get
#' `score_flag = "manual"` (the structure is declared by the user, not read
#' from the QSF). `NULL` returns `scored` unchanged.
#' @noRd
score_choice_tasks <- function(scored, choice_tasks, scheme = gfs_scheme()) {
  if (is.null(choice_tasks)) return(scored)
  if (!is.data.frame(choice_tasks)) {
    cli::cli_abort("{.arg choice_tasks} must be a data frame with columns {.field question_id}, {.field n_alternatives} and {.field n_attributes}.")
  }
  need <- c("question_id", "n_alternatives", "n_attributes")
  miss <- setdiff(need, names(choice_tasks))
  if (length(miss)) {
    cli::cli_abort("{.arg choice_tasks} is missing {cli::qty(length(miss))}column{?s} {.field {miss}}; it needs {.field question_id}, {.field n_alternatives} and {.field n_attributes}.")
  }
  ids   <- as.character(choice_tasks$question_id)
  alts  <- choice_tasks$n_alternatives
  attrs <- choice_tasks$n_attributes
  whole <- function(x) is.numeric(x) && !anyNA(x) && all(is.finite(x)) && all(x == round(x))
  if (!whole(alts) || !whole(attrs) || any(attrs < 0)) {
    cli::cli_abort("{.field n_alternatives} and {.field n_attributes} in {.arg choice_tasks} must be whole numbers, and {.field n_attributes} cannot be negative.")
  }
  if (any(alts < 2)) {
    cli::cli_abort("A stated-choice task needs at least 2 alternatives ({.field n_alternatives}); count an opt-out such as {.val neither} as an alternative.")
  }
  dup <- unique(ids[duplicated(ids)])
  if (length(dup)) {
    cli::cli_abort("{.arg choice_tasks} lists {cli::qty(length(dup))}question{?s} more than once: {.val {dup}}.")
  }
  unknown <- setdiff(ids, scored$question_id)
  if (length(unknown)) {
    cli::cli_abort(c(
      "{.arg choice_tasks} names {cli::qty(length(unknown))}question{?s} not in this survey: {.val {unknown}}.",
      i = "Use the ids in {.code score_burden()$question_id} (or {.code burden_report()$items})."
    ))
  }
  alt_pts <- ifelse(alts == 2, scheme$sc_2_alt,
                    scheme$sc_3_alt + scheme$sc_per_extra_alt * (alts - 3))
  pts <- alt_pts + scheme$sc_per_variable * attrs
  basis <- sprintf(
    "declared stated choice: %d alternatives (%.1f%s) + %d attributes x %.1f",
    as.integer(alts), alt_pts,
    ifelse(alts > 3,
           sprintf(" = %.1f + %.1f per alternative beyond 3, beyond GfS Table 1",
                   scheme$sc_3_alt, scheme$sc_per_extra_alt), ""),
    as.integer(attrs), scheme$sc_per_variable)
  set_item_scores(scored, match(ids, scored$question_id), pts, basis, scheme)
}

#' Apply the user's scoring adjustments to a [score_burden()] table, in a fixed
#' order: declared stated-choice tasks, then overrides (an override is the
#' final word on an item).
#' @noRd
adjust_scores <- function(scored, scheme = gfs_scheme(), choice_tasks = NULL,
                          overrides = NULL) {
  scored <- score_choice_tasks(scored, choice_tasks, scheme)
  score_overrides(scored, overrides, scheme)
}

#' Set points, flag "manual" and basis for rows `i`, keeping `est_seconds` in
#' step.
#' @noRd
set_item_scores <- function(scored, i, pts, basis, scheme) {
  scored$gfs_points[i]  <- pts
  if ("est_seconds" %in% names(scored)) {
    scored$est_seconds[i] <- pts / scheme$points_per_minute * 60
  }
  scored$score_flag[i]  <- "manual"
  scored$score_basis[i] <- basis
  scored
}

#' Regex: a response asks for a magnitude / quantity / date, not a category.
#' Currency words only, no symbols, to keep the source ASCII (portable-package rule).
#' @noRd
quantity_cue_pattern <- function() {
  paste0(
    "\\b(age|aged|years? old|year of birth|born|how (many|much|old|far|long)|",
    "number of|amount|minutes?|hours?|days?|weeks?|months?|years?|miles?|km|",
    "kilometres?|kg|kilograms?|litres?|percent|percentage|income|salary|earn|",
    "pounds?|dollars?|euros?|price|cost)\\b"
  )
}

#' Score one catalogue row. Returns a named list: gfs_points, score_flag, score_basis.
#' @noRd
score_item <- function(r, w) {
  fld <- function(nm, default = NULL) if (nm %in% names(r)) r[[nm]] else default
  st   <- r$std_type
  no   <- r$n_options
  flag <- r$flag %||% "auto"
  ltext <- tolower(fld("label_text") %||% "")
  qtext <- tolower(fld("question_text") %||% "")
  is_hidden <- isTRUE(fld("is_hidden", FALSE))
  is_dropdown <- isTRUE(fld("is_dropdown", FALSE))
  is_multiline <- isTRUE(fld("is_multiline", FALSE))
  is_multi_answer <- isTRUE(fld("is_multi_answer", FALSE))
  options_numeric <- isTRUE(fld("options_numeric", FALSE))
  cue <- quantity_cue_pattern()

  out <- function(pts, basis, fl = flag) {
    list(gfs_points = as.numeric(pts), score_flag = fl, score_basis = basis)
  }

  # A question hidden from the respondent carries no burden, whatever its type.
  if (is_hidden) {
    return(out(0, "hidden from the respondent via injected CSS/JS -- no response action",
               escalate(flag, "inferred")))
  }

  if (identical(st, "single_choice")) {
    if (is_dropdown) {
      # No Table 1 row for a dropdown. Map to the closest category: a rating.
      quantity <- grepl(cue, qtext, perl = TRUE) || grepl(cue, ltext, perl = TRUE)
      if (options_numeric && (quantity || (!is.na(no) && no >= 10))) {
        return(out(w$numeric_answer,
                   "dropdown of numeric options with a quantity/date cue -> GfS simple numerical answer",
                   escalate(flag, "inferred")))
      }
      pts   <- if (is.na(no) || no <= 5) w$rating_small else w$rating_large
      basis <- sprintf("dropdown, %s options -> mapped to GfS %s rating (closest Table 1 category)",
                       if (is.na(no)) "unknown" else no,
                       if (is.na(no) || no <= 5) "<=5" else ">5")
      if (!is.na(no) && no > 8 && !options_numeric) {
        basis <- paste0(basis, "; nominal_large_choice_set -- scan-and-recognise load not credited by GfS")
      }
      return(out(pts, basis, escalate(flag, "inferred")))
    }
    if (is.na(no)) {
      return(out(w$rating_small, "single choice, option count unknown -> assumed a rating <=5",
                 escalate(flag, "inferred")))
    }
    if (no <= 2) return(out(w$yes_no, "single choice, 2 options -> GfS closed yes/no"))
    if (no <= 5) return(out(w$rating_small, sprintf("single choice, %s options -> GfS rating <=5", no)))
    basis <- sprintf("single choice, %s options -> GfS rating >5", no)
    if (no > 8) basis <- paste0(basis, "; nominal_large_choice_set -- not separately credited by GfS")
    return(out(w$rating_large, basis))
  }

  if (identical(st, "multi_choice")) {
    n <- if (is.na(no) || no < 1) 1L else no
    if (n < w$multi_large_threshold) {
      return(out(w$multi_small_base + w$multi_small_per_option * (n - 1),
                 sprintf("multi-select, %s options -> GfS half-open <8: %.1f + %.1f each additional",
                         n, w$multi_small_base, w$multi_small_per_option)))
    }
    return(out(w$multi_large_base + w$multi_large_per_option * (n - 1),
               sprintf("multi-select, %s options -> GfS half-open >=8: %.1f + %.1f each additional",
                       n, w$multi_large_base, w$multi_large_per_option)))
  }

  if (identical(st, "matrix")) {
    rows <- if (is.na(r$n_rows)) 1L else r$n_rows
    if (is_multi_answer) {
      # No Table 1 rule. Each of the rows x cols cells is one trivial yes/no
      # decision, discounted for grid efficiency. Symmetric in (rows, cols) so
      # the score does not depend on the QSF's storage orientation.
      cols  <- if (is.na(r$n_cols)) 1L else r$n_cols
      cells <- rows * cols
      return(out(cells * w$matrix_cell_multi,
                 sprintf("multiple-answer grid, %s x %s = %s cells x %.1f (each cell a trivial yes/no; documented inference, not GfS)",
                         rows, cols, cells, w$matrix_cell_multi),
                 escalate(flag, "inferred")))
    }
    per <- if (!is.na(r$n_cols) && r$n_cols > 5) w$rating_large else w$rating_small
    return(out(rows * per,
               sprintf("matrix, %s rows x GfS rating %s (%.1f per row)",
                       rows, if (!is.na(r$n_cols) && r$n_cols > 5) ">5" else "<=5", per)))
  }

  if (identical(st, "open_text")) {
    essay <- is_multiline
    if (essay) return(out(w$open_essay, "multi-line text -> GfS first answer to an open question"))
    return(out(w$open_short, "single-line text -> GfS answer to a sub-question (<=5 words)"))
  }

  if (identical(st, "slider")) {
    # Slider is not in Table 1. A magnitude slider (minutes, miles, currency) is
    # a numerical answer; a graded slider (agree..disagree) is a rating.
    if (grepl(cue, ltext, perl = TRUE) || grepl(cue, qtext, perl = TRUE)) {
      return(out(w$numeric_answer,
                 "slider with a magnitude/units label -> mapped to GfS simple numerical answer",
                 escalate(flag, "inferred")))
    }
    return(out(w$slider,
               "slider, no magnitude label -> mapped to GfS rating (closest Table 1 category)",
               escalate(flag, "inferred")))
  }

  if (identical(st, "ranking"))      return(out(w$rank_base, "ranking -> GfS best-of ranking (first item)"))
  if (identical(st, "constant_sum")) return(out(w$numeric_answer,
                                                "constant sum -> approximated as a numerical answer",
                                                escalate(flag, "inferred")))

  if (identical(st, "descriptive")) {
    lines <- max(1, ceiling((r$text_words %||% 0L) / w$words_per_line))
    extra <- max(0, lines - 3)
    return(out(w$descriptive_base + w$descriptive_per_extra_line * extra,
               sprintf("transition/instruction text: %s words / %s words-per-line -> %s estimated lines -> %.1f + %.1f x %s",
                       r$text_words %||% 0L, w$words_per_line, lines,
                       w$descriptive_base, w$descriptive_per_extra_line, extra)))
  }

  if (identical(st, "timing")) return(out(0, "page-timing metadata -- not shown, no response action"))
  if (identical(st, "meta"))   return(out(0, "browser/metadata capture -- no response action"))
  if (identical(st, "captcha")) return(out(w$captcha, "captcha -- minimal fixed interaction cost"))

  out(NA_real_, "unrecognised Qualtrics question type -- not scored", "unknown")
}

#' Move a flag towards less certainty, never back towards "auto".
#' @noRd
escalate <- function(current, to) {
  rank <- c(auto = 1L, inferred = 2L, manual = 3L, unknown = 4L)
  if (is.na(rank[current] %||% NA) || rank[to] > rank[current]) to else current
}
