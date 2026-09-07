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

  rows <- lapply(seq_len(nrow(blocks)), function(bi) {
    blk <- blocks[bi, ]
    qids <- blk$question_ids[[1]]
    lapply(qids, function(qid) {
      payload <- questions[[qid]]
      if (is.null(payload)) {
        cli::cli_warn("Block {.val {blk$block_name}} lists {.val {qid}} but no such question element exists; skipping.")
        return(NULL)
      }
      cls <- classify_question(payload)
      cls$flow_order  <- blk$flow_order
      cls$block_id    <- blk$block_id
      cls$block_name  <- blk$block_name
      cls$in_loop     <- blk$in_loop
      cls$loop_max    <- blk$loop_max
      cls
    })
  })

  cat_tbl <- do.call(rbind, unlist(rows, recursive = FALSE))
  cat_tbl[c(
    "question_id", "flow_order", "block_id", "block_name",
    "std_type", "qualtrics_type", "selector", "subselector",
    "n_options", "n_rows", "n_cols", "text_words", "max_label_words",
    "label_text", "options_numeric", "question_text", "is_hidden",
    "has_display_logic", "display_logic_refs", "has_validation",
    "in_loop", "loop_max", "flag"
  )]
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
