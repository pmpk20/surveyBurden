#' Parse a Qualtrics `.qsf` into a standardised question catalogue
#'
#' The Layer 1 entry point. Reads the file (or an already-loaded object),
#' resolves the flow-reachable blocks, and classifies every live question into a
#' standardised type with the structural fields the burden scorer needs.
#'
#' This function does not resolve respondent paths or compute burden. It reads
#' and classifies questions.
#'
#' @param x A path to a `.qsf` file, or a `qsf_raw` object from [read_qsf()].
#'
#' @return A [tibble][tibble::tibble], one row per live question, ordered by flow
#'   position then within-block position. Columns:
#'   `question_id`, `flow_order`, `block_id`, `block_name`, `std_type`,
#'   `qualtrics_type`, `selector`, `subselector`, `n_options`, `n_rows`,
#'   `n_cols`, `text_words`, `max_label_words`, `label_text` (response/answer
#'   option labels, lowercased and joined; `NA` if none), `options_numeric`
#'   (`TRUE` if every response option label is a number), `question_text`
#'   (HTML-stripped, truncated to 200 characters), `is_hidden` (`TRUE` if the
#'   question is hidden from the respondent via injected CSS/JS),
#'   `has_display_logic`, `display_logic_refs`, `has_validation`, `in_loop`,
#'   `loop_max`, `flag`.
#'
#' @export
parse_qsf <- function(x) {
  qsf <- if (inherits(x, "qsf_raw")) x else read_qsf(x)

  blocks <- resolve_live_blocks(qsf)
  questions <- index_questions(qsf)

  rows <- list()
  for (bi in seq_len(nrow(blocks))) {
    blk  <- blocks[bi, ]
    for (qid in blk$question_ids[[1]]) {
      payload <- questions[[qid]]
      if (is.null(payload)) {
        cli::cli_warn("Block {.val {blk$block_name}} lists {.val {qid}} but no such question element exists; skipping.")
        next
      }
      cls <- classify_question(payload)
      cls$flow_order <- blk$flow_order
      cls$block_id   <- blk$block_id
      cls$block_name <- blk$block_name
      cls$in_loop    <- isTRUE(blk$in_loop)
      cls$loop_max   <- as.integer(blk$loop_max)
      rows[[length(rows) + 1L]] <- cls
    }
  }

  catalogue_tibble(rows)
}

#' Assemble the [parse_qsf()] catalogue tibble (one row per question) from the
#' list of per-question lists returned by [classify_question()] plus block
#' context. One tibble built once, rather than one per question then rbind.
#' @noRd
catalogue_tibble <- function(rows) {
  chr <- function(f) vapply(rows, function(r) {
    v <- r[[f]]; if (is.null(v) || length(v) != 1L) NA_character_ else as.character(v)
  }, character(1))
  int <- function(f) vapply(rows, function(r) {
    v <- r[[f]]; if (is.null(v) || length(v) != 1L) NA_integer_ else as.integer(v)
  }, integer(1))
  lgl <- function(f) vapply(rows, function(r) isTRUE(r[[f]]), logical(1))

  tibble::tibble(
    question_id        = chr("question_id"),
    flow_order         = int("flow_order"),
    block_id           = chr("block_id"),
    block_name         = chr("block_name"),
    std_type           = chr("std_type"),
    qualtrics_type     = chr("qualtrics_type"),
    selector           = chr("selector"),
    subselector        = chr("subselector"),
    n_options          = int("n_options"),
    n_rows             = int("n_rows"),
    n_cols             = int("n_cols"),
    text_words         = int("text_words"),
    max_label_words    = int("max_label_words"),
    label_text         = chr("label_text"),
    options_numeric    = lgl("options_numeric"),
    question_text      = chr("question_text"),
    is_hidden          = lgl("is_hidden"),
    has_display_logic  = lgl("has_display_logic"),
    display_logic_refs = lapply(rows, function(r) r$display_logic_refs %||% character(0)),
    has_validation     = lgl("has_validation"),
    in_loop            = lgl("in_loop"),
    loop_max           = int("loop_max"),
    flag               = chr("flag")
  )
}

#' Index every `SQ` payload by its QuestionID
#' @noRd
index_questions <- function(qsf) {
  payloads <- qsf_elements(qsf, "SQ")
  names(payloads) <- vapply(
    payloads,
    function(p) p$QuestionID %||% NA_character_,
    character(1)
  )
  payloads
}
