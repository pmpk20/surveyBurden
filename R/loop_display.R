# Display logic inside Loop & Merge blocks: gate classification and shared
# item flags used by the structural profile and the traversal output.

#' Split the display-logic gates of a loop block's conditional questions.
#'
#' `iter`: triggers that are questions in the same loop block (Qualtrics reads
#' the current iteration's answer, so they take a fresh state per iteration).
#' `shared`: every other gate (questions outside the block, stored fields);
#' one state for all iterations. `position`: whether any question uses the
#' iteration-position gate `@@iter`.
#' @return list(iter = chr, shared = chr, position = lgl)
#' @noRd
classify_loop_gates <- function(qids, loop_bid, parsed, qblock) {
  vars <- unique(unlist(lapply(qids, function(q) parsed[[q]]$vars)))
  position <- "@@iter" %in% vars
  vars <- setdiff(vars, "@@iter")
  in_block <- !startsWith(vars, "@") & vars %in% names(qblock) &
    qblock[vars] %in% loop_bid
  list(iter = vars[in_block], shared = vars[!in_block], position = position)
}

#' Visible and responsive flags per item, by the rules respondent_burden()
#' uses: timing and metadata items and hidden items are not visible;
#' descriptive text, timing and metadata items are not responsive.
#' @return list(visible = named lgl, responsive = named lgl)
#' @noRd
item_flags <- function(scored) {
  qt <- stats::setNames(scored$qualtrics_type, scored$question_id)
  hidden <- scored$is_hidden %in% TRUE
  list(visible    = stats::setNames(!qt %in% c("Timing", "Meta") & !hidden, names(qt)),
       responsive = stats::setNames(!qt %in% c("DB", "Timing", "Meta"), names(qt)))
}

#' Questions whose response is forced: `Validation$Settings$ForceResponse`
#' exactly `"ON"` (a soft `"RequestResponse"` does not count).
#' @return named logical, one per question
#' @noRd
force_response_map <- function(qsf) {
  sq <- qsf_elements(qsf, "SQ")
  ids <- vapply(sq, function(p) p$QuestionID %||% NA_character_, character(1))
  on  <- vapply(sq, function(p) identical(p$Validation$Settings$ForceResponse, "ON"), logical(1))
  stats::setNames(on, ids)
}
