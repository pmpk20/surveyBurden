#' Validate (and coerce) a question catalogue
#'
#' Checks that a data frame has the columns [score_burden()] needs and coerces
#' it to a tibble.
#'
#' A catalogue from [parse_qsf()] always passes. This function is useful when
#' you construct a catalogue by hand for a non-Qualtrics survey: it confirms the
#' required columns are present, fills optional columns with safe defaults, and
#' converts the result to a tibble so downstream functions work unchanged.
#'
#' @param catalogue A data frame (or tibble) with at least the columns
#'   `question_id` and `std_type`. See **Details** for the full schema.
#'
#' @details
#' **Required columns** (must be present):
#' \describe{
#'   \item{`question_id`}{Character. Unique identifier for each question.}
#'   \item{`std_type`}{Character. Standardised question type: one of
#'     `"single_choice"`, `"multi_choice"`, `"matrix"`, `"open_text"`,
#'     `"slider"`, `"ranking"`, `"constant_sum"`, `"descriptive"`, `"timing"`,
#'     `"meta"`, `"captcha"`.}
#' }
#'
#' **Structural columns** (used by the scorer; default to safe values if
#' missing):
#' \describe{
#'   \item{`n_options`}{Integer. Number of response options (`NA` if unknown).}
#'   \item{`n_rows`}{Integer. Number of matrix rows (`NA` for non-matrix types).}
#'   \item{`n_cols`}{Integer. Number of matrix columns (`NA` for non-matrix types).}
#'   \item{`text_words`}{Integer. Word count of the question stem.}
#'   \item{`is_dropdown`}{Logical. `TRUE` if a single-choice dropdown.}
#'   \item{`is_multiline`}{Logical. `TRUE` if a multi-line open-text field.}
#'   \item{`is_multi_answer`}{Logical. `TRUE` if a checkbox-per-cell matrix.}
#'   \item{`is_hidden`}{Logical. `TRUE` if hidden from the respondent.}
#'   \item{`options_numeric`}{Logical. `TRUE` if all option labels are numbers.}
#'   \item{`label_text`}{Character. Lowercased, joined response labels.}
#'   \item{`question_text`}{Character. Plain-text question stem.}
#'   \item{`has_display_logic`}{Logical. Whether the question has display logic.}
#'   \item{`has_validation`}{Logical. Whether a response is forced.}
#'   \item{`in_loop`}{Logical. Whether the question is inside a loop block.}
#'   \item{`loop_max`}{Integer. Maximum loop iterations (`NA` if not in loop).}
#'   \item{`flag`}{Character. Confidence flag (`"auto"`, `"inferred"`,
#'     `"manual"`, or `"unknown"`).}
#' }
#'
#' **Platform-specific columns** (retained for provenance; not used by the
#' scorer):
#' \describe{
#'   \item{`qualtrics_type`}{Character. Original Qualtrics `QuestionType`.}
#'   \item{`selector`}{Character. Qualtrics `Selector`.}
#'   \item{`subselector`}{Character. Qualtrics `SubSelector`.}
#' }
#'
#' @return A tibble with all required, structural, and platform-specific columns
#'   present (missing optional columns filled with their defaults).
#'
#' @examples
#' # Hand-craft a tiny catalogue
#' cat <- data.frame(
#'   question_id = c("Q1", "Q2", "Q3"),
#'   std_type    = c("single_choice", "open_text", "matrix"),
#'   n_options   = c(5L, NA, NA),
#'   n_rows      = c(NA, NA, 4L),
#'   n_cols      = c(NA, NA, 5L),
#'   stringsAsFactors = FALSE
#' )
#' validated <- validate_catalogue(cat)
#' validated
#'
#' @export
validate_catalogue <- function(catalogue) {
  if (!is.data.frame(catalogue)) {
    cli::cli_abort("{.arg catalogue} must be a data frame or tibble.")
  }
  nms <- names(catalogue)

  required <- c("question_id", "std_type")
  missing_req <- setdiff(required, nms)
  if (length(missing_req)) {
    cli::cli_abort("Missing required column{?s}: {.field {missing_req}}.")
  }

  defaults <- list(
    n_options        = NA_integer_,
    n_rows           = NA_integer_,
    n_cols           = NA_integer_,
    text_words       = NA_integer_,
    max_label_words  = NA_integer_,
    label_text       = NA_character_,
    options_numeric  = FALSE,
    question_text    = NA_character_,
    is_hidden        = FALSE,
    is_dropdown      = FALSE,
    is_multiline     = FALSE,
    is_multi_answer  = FALSE,
    has_display_logic = FALSE,
    display_logic_refs = replicate(nrow(catalogue), character(0), simplify = FALSE),
    has_validation   = FALSE,
    in_loop          = FALSE,
    loop_max         = NA_integer_,
    flag             = "auto",
    qualtrics_type   = NA_character_,
    selector         = NA_character_,
    subselector      = NA_character_,
    flow_order       = NA_integer_,
    block_id         = NA_character_,
    block_name       = NA_character_
  )

  for (col in names(defaults)) {
    if (!col %in% nms) {
      val <- defaults[[col]]
      if (is.list(val)) {
        catalogue[[col]] <- val
      } else {
        catalogue[[col]] <- rep(val, nrow(catalogue))
      }
    }
  }

  nms <- names(catalogue)
  if ("selector" %in% nms && "std_type" %in% nms) {
    if (all(!catalogue$is_dropdown)) {
      catalogue$is_dropdown <- catalogue$std_type == "single_choice" &
        !is.na(catalogue$selector) & catalogue$selector == "DL"
    }
    if (all(!catalogue$is_multiline)) {
      catalogue$is_multiline <- catalogue$std_type == "open_text" &
        !is.na(catalogue$selector) & catalogue$selector %in% c("ML", "ESTB", "FORM")
    }
  }
  if ("subselector" %in% nms && "std_type" %in% nms) {
    if (all(!catalogue$is_multi_answer)) {
      catalogue$is_multi_answer <- catalogue$std_type == "matrix" &
        !is.na(catalogue$subselector) & catalogue$subselector == "MultipleAnswer"
    }
  }

  tibble::as_tibble(catalogue)
}
