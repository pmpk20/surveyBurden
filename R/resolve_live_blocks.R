#' Resolve the survey blocks a respondent can actually reach
#'
#' Walks the `SurveyFlow` and returns the blocks it references, in flow order,
#' with their questions. Blocks that exist in the `.qsf` but are not shown by the
#' flow (typically the Qualtrics "Trash / Unused Questions" block) are excluded.
#'
#' @param qsf A `qsf_raw` object from [read_qsf()].
#'
#' @return A [tibble][tibble::tibble] with one row per live block:
#'   \describe{
#'     \item{flow_order}{Integer position in the flow (first occurrence).}
#'     \item{block_id}{Qualtrics block id (`BL_...`).}
#'     \item{block_name}{Block description.}
#'     \item{in_loop}{`TRUE` if the block uses Loop & Merge.}
#'     \item{loop_on_qid}{Question id the loop count depends on, else `NA`.}
#'     \item{loop_max}{Maximum loop iterations, else `NA`.}
#'     \item{question_ids}{List column: character vector of `QID`s in block order.}
#'   }
#'
#' @export
resolve_live_blocks <- function(qsf) {
  if (!inherits(qsf, "qsf_raw")) {
    cli::cli_abort("{.arg qsf} must be a {.cls qsf_raw} object from {.fn read_qsf}.")
  }

  # 1. Ordered, de-duplicated list of block ids referenced by the flow.
  referenced <- character(0)
  flow_walk(qsf_flow(qsf)$Flow, function(node) {
    if (node$Type %in% c("Standard", "Block") && !is.null(node$ID)) {
      referenced <<- c(referenced, node$ID)
    }
  })
  referenced <- unique(referenced)

  # 2. Index block definitions by id.
  defs <- qsf_block_defs(qsf)
  names(defs) <- vapply(defs, function(b) b$ID %||% NA_character_, character(1))

  # 3. Build one row per referenced block, in flow order.
  rows <- lapply(seq_along(referenced), function(i) {
    id <- referenced[[i]]
    b <- defs[[id]]
    if (is.null(b)) {
      cli::cli_warn("Flow references block {.val {id}} which has no definition; skipping.")
      return(NULL)
    }
    loop <- block_loop_info(b)
    tibble::tibble(
      flow_order   = i,
      block_id     = id,
      block_name   = b$Description %||% NA_character_,
      in_loop      = loop$in_loop,
      loop_on_qid  = loop$loop_on_qid,
      loop_max     = loop$loop_max,
      question_ids = list(block_question_ids(b))
    )
  })

  out <- do.call(rbind, rows)
  out$flow_order <- seq_len(nrow(out))
  out
}

#' QIDs of a block's questions, in order (page breaks skipped)
#' @noRd
block_question_ids <- function(b) {
  els <- b$BlockElements %||% list()
  is_q <- vapply(els, function(e) identical(e$Type, "Question"), logical(1))
  vapply(els[is_q], function(e) e$QuestionID %||% NA_character_, character(1))
}

#' Loop & Merge metadata for a block
#' @noRd
block_loop_info <- function(b) {
  opts <- b$Options %||% list()
  if (is.null(opts$Looping)) {
    return(list(in_loop = FALSE, loop_on_qid = NA_character_, loop_max = NA_integer_))
  }
  lo <- opts$LoopingOptions %||% list()
  locator <- lo$Locator %||% ""
  v <- suppressWarnings(as.integer(sub(".*\\?v=([0-9]+).*", "\\1", locator)))
  if (is.na(v) && length(lo$Static)) v <- length(lo$Static)
  list(
    in_loop     = TRUE,
    loop_on_qid = lo$QID %||% NA_character_,
    loop_max    = v
  )
}
