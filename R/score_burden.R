#' Score per-question ex-ante burden
#'
#' Applies the GfS / Axhausen scoring rules ([gfs_weights()]) to a question
#' catalogue from [parse_qsf()], adding GfS burden points, an estimated
#' completion time, a confidence flag and a plain-language rationale per item.
#' This is Layer 3 at the item level; propagation through respondent paths is a
#' later step.
#'
#' The published GfS Table 1 point weights are applied directly where the
#' required structure can be read from the QSF. Where the QSF does not contain
#' the quantity GfS needs -- a dropdown has no Table 1 row, a slider is not in
#' the scheme, "lines" of text are not in a QSF -- the package applies an
#' explicit, documented inference rule. `score_flag` and `score_basis` say
#' which case each item is.
#'
#' @param catalogue A tibble from [parse_qsf()].
#' @param weights A named list of weights; defaults to [gfs_weights()].
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
#' @export
score_burden <- function(catalogue, weights = gfs_weights()) {
  if (!tibble::is_tibble(catalogue) || !"std_type" %in% names(catalogue)) {
    cli::cli_abort("{.arg catalogue} must be a tibble from {.fn parse_qsf}.")
  }

  cols <- as.list(catalogue)
  rows <- lapply(seq_len(nrow(catalogue)),
                 function(i) lapply(cols, function(col) col[[i]]))
  scored <- lapply(rows, score_item, weights)

  gfs <- vapply(scored, `[[`, numeric(1), "gfs_points")
  catalogue$gfs_points  <- gfs
  catalogue$est_seconds <- gfs / weights$points_per_minute * 60
  catalogue$score_flag  <- vapply(scored, `[[`, character(1), "score_flag")
  catalogue$score_basis <- vapply(scored, `[[`, character(1), "score_basis")
  catalogue
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
  sel  <- r$selector %||% NA_character_
  no   <- r$n_options
  flag <- r$flag %||% "auto"
  ltext <- tolower(fld("label_text") %||% "")
  qtext <- tolower(fld("question_text") %||% "")
  is_hidden <- isTRUE(fld("is_hidden", FALSE))
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
    if (identical(sel, "DL")) {
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
    if (identical(r$subselector, "MultipleAnswer")) {
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
    essay <- isTRUE(sel %in% c("ML", "ESTB", "FORM"))
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
