#' Realised exposure: the blocks each respondent was routed into and the
#' burden they were shown there
#'
#' For every respondent, including those who broke off or were screened out,
#' walks the survey flow against their own answers and returns, per block,
#' whether the flow routed them into it and the GfS+ points, items and pages
#' of the questions it **showed** them. Unlike [realised_burden()], which
#' scores what was answered, a question shown but left blank counts here, so
#' the block a respondent left in is not understated. The result is the input
#' for a break-off (discrete-time hazard) model; see
#' [exposure_person_period()].
#'
#' **What is evaluated.** Branch logic in the survey flow and display logic on
#' questions are evaluated per respondent, in flow order, so that
#' `Displayed()` literals see earlier decisions. Supported literals:
#' question `Selected` / `NotSelected` (single choice, multiple choice and
#' matrix cells, via the QSF `RecodeValues`), `Displayed` / `NotDisplayed`,
#' `Empty` / `NotEmpty` and numeric or text comparisons on a question's entry
#' value, embedded-data comparisons, and the Loop & Merge "current loop"
#' test. Embedded fields are read from a response column of the same name
#' (matched exactly, then ignoring case, then ignoring case and
#' punctuation), or from a fixed value set in the flow. A fixed value set in
#' the flow holds from that point on, so a field set more than once is read
#' as it stood at each branch. A cell holding several choice codes joined by
#' commas (`"1,4"`) is split only when every piece is one of the question's
#' choice codes, so a choice label containing a comma is never split.
#'
#' **What cannot be evaluated** (an unsupported literal such as a quota test,
#' an embedded field with no column and no fixed value -- typically one set by
#' question JavaScript -- or a trigger question with no response columns) is
#' never silently treated as true or false. Three-valued logic is used, so an
#' unknown literal matters only when it decides the outcome. When it does:
#' a question counts as shown if the respondent answered it, and is counted in
#' `unresolved_items`; a branch counts as taken if the respondent answered a
#' question in a block inside it (or, for a branch that ends the survey, if
#' they finished without answering anything later), and is counted in the
#' `respondents` attribute's `n_unresolved_branches`.
#'
#' **Exit.** A respondent's exit is the furthest block they reached:
#' by default the last block in which they answered a question
#' (`furthest = "answered"`). Someone who leaves on a newly displayed page
#' without answering is therefore attributed to the previous block; supply a
#' last-seen block or question in `furthest_col` to avoid this. Respondents
#' marked finished reached every block the flow routed them into. Blocks after
#' the exit have `routed_in = NA`: the flow beyond that point depends on
#' answers that were never given. Qualtrics records a screened-out response as
#' finished, so a respondent marked unfinished is a break-off, never a
#' screen-out.
#'
#' **Loops.** The iterations a Loop & Merge block ran are taken from the
#' question driving the loop (the numeric response, or the selected choices)
#' when that answer is available, else from the iterations with any answer
#' (`loop_iterations = "observed"` forces the latter). Iterations with answers
#' are always counted. In the exit block of a break-off, only iterations up to
#' the last one answered are counted. Export columns number a choice-driven
#' loop by the choice's position, so iteration `j` is the driving question's
#' `j`-th choice. A randomised loop is not shown in export order: at a
#' break-off only the iterations answered count, and where the driver cannot
#' settle the iterations, or the loop presents only a subset of them, they
#' come from the answers alone. Those respondents are flagged in
#' `unresolved_loops`, as are respondents in loops whose size the QSF does not
#' give.
#'
#' Answers that contradict the evaluated flow (answers in a block the flow
#' did not route the respondent into) are trusted: the block counts as routed
#' in, and the respondent's `n_routing_conflicts` is incremented.
#'
#' @inheritParams realised_burden
#' @param furthest How to find the furthest block a respondent reached:
#'   `"answered"` (default) uses the last block with an answer; `"column"`
#'   reads `furthest_col`.
#' @param furthest_col Name of a column holding, per respondent, the last block
#'   reached: a block id, a block name, a question id (its block is used) or
#'   a whole-number block ordinal (`flow_order` from [resolve_live_blocks()]),
#'   matched in that order, so a block named `"2"` is that block. Blank or
#'   unrecognised values fall back to `"answered"`.
#' @param id_col Name of the respondent-id column (see [realised_burden()]).
#'   Its values must be unique and not missing; Qualtrics' `ResponseId` is.
#' @param loop_iterations `"driver"` (default) or `"observed"`; see Loops.
#' @param embedded Optional named character vector mapping embedded-data field
#'   names to response columns, e.g. `c(TotalVehicles = "total_vehicles")`.
#'   Overrides the automatic matching for the fields it names.
#'
#' @return A [tibble][tibble::tibble], one row per respondent per live block,
#'   in flow order:
#'   \describe{
#'     \item{`response_id`}{Respondent identifier.}
#'     \item{`block_id`, `block_name`, `flow_order`}{The block.}
#'     \item{`outcome`}{The respondent's outcome: `"complete"`,
#'       `"breakoff"` or `"screen_out"` (the flow ended the survey early).}
#'     \item{`routed_in`}{`TRUE` if the flow routed the respondent into the
#'       block, `FALSE` if it did not, `NA` for blocks after their exit.}
#'     \item{`displayed`}{`TRUE` if the block showed at least one visible
#'       question (Qualtrics skips a block whose questions are all hidden).}
#'     \item{`iterations`}{Loop & Merge iterations shown; `NA` for other
#'       blocks.}
#'     \item{`shown_points`}{GfS+ points of the questions shown (each loop
#'       iteration counted).}
#'     \item{`shown_items`, `shown_response_items`}{Visible questions shown,
#'       and those of them that take a response (not descriptive text).}
#'     \item{`shown_hidden_items`}{Items the respondent passed that are never
#'       visible (hidden by injected CSS/JS, page timing, metadata). They score
#'       0 points and are not in `shown_items`; reported for completeness.}
#'     \item{`shown_pages`}{Pages shown: a page counts when a visible question
#'       on it is shown.}
#'     \item{`design_points`}{The block's design score (its questions scored
#'       once), as in `burden_report()$blocks`.}
#'     \item{`exit_block`}{`TRUE` on the block the respondent left the survey
#'       in (break-offs and screen-outs only).}
#'     \item{`unresolved_items`}{Shown-or-not decisions in this block that the
#'       logic could not settle and that fell back to answered/not answered.}
#'   }
#'   Shown counts are `NA` where `routed_in` is `NA`, and 0 where it is
#'   `FALSE`. The attribute `respondents` holds one row per respondent:
#'   `response_id`, `finished`, `outcome`, `furthest_order`,
#'   `n_unresolved_items`, `n_unresolved_branches`, `unresolved_loops`
#'   (`TRUE` if a loop's iterations could not be recovered), and
#'   `n_routing_conflicts`.
#'
#' @seealso [exposure_person_period()] to turn the result into hazard data;
#'   [realised_burden()] for the answer-based total.
#'
#' @examples
#' qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
#'                          package = "surveyBurden")
#' responses <- data.frame(
#'   ResponseId = c("R_1", "R_2", "R_3"),
#'   Finished   = c(1, 0, 1),
#'   QID2  = c("1", "1", "2"),   # consent: R_3 declines and is screened out
#'   QID3  = c("1", "1", NA),
#'   QID4  = c("2", "3", NA),
#'   QID6  = c("1", "4", NA),    # R_1 employed: routed into Commuting
#'   QID9  = c("2", NA, NA),     # two adults: the loop runs twice
#'   QID10 = c("1", NA, NA),
#'   `1_QID11` = c("2", NA, NA),
#'   QID19_1 = c("3", NA, NA),
#'   QID22 = c("3", NA, NA),
#'   QID26 = c("1", NA, NA),
#'   check.names = FALSE
#' )
#' ex <- realised_exposure(qsf_path, responses)
#' ex[ex$response_id == "R_1", c("block_name", "routed_in", "shown_points")]
#' attr(ex, "respondents")
#'
#' @export
realised_exposure <- function(qsf, responses, scheme = gfs_scheme(), id_col = NULL,
                              furthest = c("answered", "column"), furthest_col = NULL,
                              loop_iterations = c("driver", "observed"),
                              embedded = NULL) {
  furthest <- match.arg(furthest)
  loop_iterations <- match.arg(loop_iterations)
  if (!inherits(qsf, "qsf_raw")) qsf <- read_qsf(qsf)
  responses <- read_responses(responses)
  if (identical(furthest, "column")) {
    if (is.null(furthest_col) || !furthest_col %in% names(responses)) {
      cli::cli_abort("{.arg furthest_col} must name a column of {.arg responses} when {.code furthest = \"column\"}.")
    }
  }
  responses <- drop_qualtrics_header_rows(responses)$data
  n <- nrow(responses)
  if (n == 0L) cli::cli_abort("{.arg responses} has no respondents.")

  catalogue <- parse_qsf(qsf)
  blocks    <- resolve_live_blocks(qsf)
  scored    <- score_burden(catalogue, scheme)
  payloads  <- index_questions(qsf)
  nb        <- nrow(blocks)

  q <- list(
    gfs     = stats::setNames(scored$gfs_points, scored$question_id),
    qtype   = stats::setNames(scored$qualtrics_type, scored$question_id),
    hidden  = stats::setNames(scored$is_hidden %in% TRUE, scored$question_id),
    block   = stats::setNames(scored$block_id, scored$question_id)
  )
  q$gfs[is.na(q$gfs)] <- 0
  q$visible    <- stats::setNames(!q$qtype %in% c("Timing", "Meta") & !q$hidden,
                                  names(q$qtype))
  q$responsive <- stats::setNames(!q$qtype %in% c("DB", "Timing", "Meta"), names(q$qtype))
  pages <- block_pages(qsf)

  # ---- response columns ------------------------------------------------------
  cols <- exposure_columns(qsf, responses, scored$question_id)
  id_col  <- resolve_id_col(responses, id_col)
  resp_id <- if (!is.null(id_col)) responses[[id_col]] else seq_len(n)
  if (is.factor(resp_id)) resp_id <- as.character(resp_id)
  n_na <- sum(is.na(resp_id)); n_dup <- sum(duplicated(resp_id) & !is.na(resp_id))
  if (n_na + n_dup > 0L) {
    cli::cli_abort(c(
      "Respondent ids must be unique and not missing.",
      x = "{.field {id_col}} has {n_na} missing and {n_dup} duplicated value{?s}.",
      i = "Name the unique respondent column with {.arg id_col} (in Qualtrics exports, {.field ResponseId})."
    ))
  }
  fin     <- detect_finished(responses)

  ctx <- exposure_context(responses, cols, payloads, blocks, q, n)
  emb <- embedded_columns(qsf, responses, embedded)

  # ---- which blocks have answers; the furthest block reached ----------------
  ans_block <- vapply(seq_len(nb), function(k) {
    qs <- blocks$question_ids[[k]]
    Reduce(`|`, lapply(qs, ctx$answered_any), init = rep(FALSE, n))
  }, logical(n))
  if (is.null(dim(ans_block))) ans_block <- matrix(ans_block, nrow = n)
  last_ans <- apply(ans_block, 1, function(r) if (any(r)) max(which(r)) else 0L)
  furthest_ord <- as.numeric(pmax(last_ans, 1L))
  if (identical(furthest, "column")) {
    fc <- furthest_from_column(responses[[furthest_col]], blocks, q$block)
    use <- !is.na(fc)
    if (any(!use)) {
      cli::cli_inform("{sum(!use)} respondent{?s} with a blank or unrecognised {.field {furthest_col}}: furthest block taken from their answers.")
    }
    furthest_ord[use] <- fc[use]
  }
  furthest_obs <- furthest_ord        # before completes are set to Inf
  furthest_ord[fin %in% TRUE] <- Inf

  # ---- walk the flow -------------------------------------------------------
  walk <- exposure_walk(qsf, blocks, ctx, emb, ans_block, last_ans, fin,
                        loop_iterations, furthest_ord)

  # ---- outcome ---------------------------------------------------------------
  # Screened out: the flow ended the survey early at a point the respondent
  # reached, with no answers after it. Qualtrics marks a screened-out
  # response finished, so an unfinished respondent is a break-off whatever
  # the flow says beyond their exit (that part is evaluated on answers never
  # given). With completion unknown, the end must come no later than their
  # furthest block.
  end_reached <- walk$ended &
    (fin %in% TRUE | (is.na(fin) & walk$end_pos <= furthest_obs))
  screened <- walk$ended_early & end_reached & !(last_ans > walk$end_pos)
  outcome <- ifelse(fin %in% TRUE, "complete", "breakoff")
  unknown <- is.na(fin)
  if (any(unknown)) {
    last_routed <- apply(walk$routed, 1, function(r) if (any(r)) max(which(r)) else 0L)
    outcome[unknown] <- ifelse(last_ans[unknown] >= last_routed[unknown],
                               "complete", "breakoff")
    furthest_ord[unknown & outcome == "complete"] <- Inf
  }
  outcome[screened] <- "screen_out"
  furthest_ord[screened] <- Inf

  # ---- assemble per block ---------------------------------------------------
  design <- tapply(scored$gfs_points, scored$block_id, sum, na.rm = TRUE)
  rows <- vector("list", nb)
  exit_cand <- matrix(FALSE, n, nb)
  unres_loop <- rep(FALSE, n)
  for (k in seq_len(nb)) {
    bid <- blocks$block_id[k]
    routed_in <- walk$routed[, k]
    routed_in[k > furthest_ord & !end_reached & !routed_in] <- NA
    routed_in[k > furthest_ord & routed_in %in% TRUE] <- NA
    rr <- routed_in %in% TRUE
    unres_loop <- unres_loop | (walk$unres_loop[, k] & rr)
    a <- lapply(assemble_block(k, blocks, walk, q, pages, rr, outcome, furthest_ord, ctx, n),
                unname)
    na <- is.na(routed_in)
    for (nm in c("shown_points", "shown_items", "shown_response_items", "shown_pages",
                 "unresolved_items", "iterations", "shown_hidden_items")) {
      if (length(a[[nm]]) == n) a[[nm]][na] <- NA
    }
    displayed <- a$shown_pages > 0
    exit_cand[, k] <- rr & displayed %in% TRUE
    rows[[k]] <- tibble::tibble(
      .row = seq_len(n), response_id = resp_id, block_id = bid,
      block_name = blocks$block_name[k], flow_order = blocks$flow_order[k],
      outcome = outcome, routed_in = routed_in, displayed = displayed,
      iterations = if (isTRUE(blocks$in_loop[k])) a$iterations else NA_integer_,
      shown_points = a$shown_points, shown_items = a$shown_items,
      shown_response_items = a$shown_response_items, shown_pages = a$shown_pages,
      design_points = as.numeric(design[bid] %||% 0),
      shown_hidden_items = a$shown_hidden_items,
      exit_block = FALSE, unresolved_items = a$unresolved_items
    )
  }

  # exit block: last displayed block reached (else last block routed into)
  exit_k <- apply(exit_cand, 1, function(r) if (any(r)) max(which(r)) else NA_integer_)
  fallback <- apply(walk$routed, 1, function(r) if (any(r)) max(which(r)) else 1L)
  exit_k <- ifelse(is.na(exit_k), pmin(fallback, pmax(1L, last_ans)), exit_k)
  exit_k[outcome == "complete"] <- NA_integer_
  for (k in seq_len(nb)) rows[[k]]$exit_block <- exit_k %in% k

  out <- do.call(rbind, rows)
  out <- out[order(out$.row, out$flow_order), ]
  rand_k <- which(vapply(blocks$block_id, function(b) isTRUE(walk$loop_random[[b]]), TRUE))
  exit_random <- outcome == "breakoff" & is.finite(furthest_ord) & furthest_ord %in% rand_k
  unres_items <- tapply(out$unresolved_items, factor(out$.row, seq_len(n)),
                        function(v) sum(v, na.rm = TRUE))
  out$.row <- NULL

  respondents <- tibble::tibble(
    response_id           = resp_id,
    finished              = fin,
    outcome               = outcome,
    furthest_order        = ifelse(is.finite(furthest_ord), furthest_ord, NA_real_),
    n_unresolved_items    = as.integer(unres_items),
    n_unresolved_branches = as.integer(walk$unres_branch),
    unresolved_loops      = unres_loop | exit_random,
    n_routing_conflicts   = as.integer(walk$conflicts)
  )
  if (sum(respondents$n_unresolved_items) + sum(respondents$n_unresolved_branches) > 0L) {
    cli::cli_inform(c(
      i = paste("Logic not settled by the data for {sum(respondents$n_unresolved_items > 0 |",
                "respondents$n_unresolved_branches > 0)} respondent{?s}: {sum(respondents$n_unresolved_items)}",
                "question decision{?s} and {sum(respondents$n_unresolved_branches)} branch decision{?s}",
                "fell back to whether they answered."),
      i = "See {.code attr(x, \"respondents\")}."
    ))
  }
  attr(out, "respondents") <- respondents
  out
}


#' Person-period (hazard) data from realised exposure
#'
#' Turns [realised_exposure()] output into one row per respondent per block at
#' risk, ready for a discrete-time hazard model of break-off. A respondent is at
#' risk in a block they were routed into and that displayed at least one
#' question; the block they left in is always kept.
#'
#' @param x Output of [realised_exposure()].
#'
#' @return A [tibble][tibble::tibble] with the columns of `x` for the rows at
#'   risk, plus `period` (1, 2, ... within respondent), `event` (1 on the exit
#'   row of a break-off, else 0; screen-outs and completes are censored),
#'   `points_before` (GfS+ points shown in earlier blocks) and `block_points`
#'   (the block's design score, `design_points`).
#'
#' @examples
#' qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
#'                          package = "surveyBurden")
#' responses <- data.frame(
#'   ResponseId = c("R_1", "R_2"), Finished = c(1, 0),
#'   QID2 = c("1", "1"), QID3 = c("1", "1"), QID4 = c("2", "3"),
#'   QID6 = c("1", "4"), QID9 = c("1", NA), QID26 = c("1", NA)
#' )
#' pp <- exposure_person_period(realised_exposure(qsf_path, responses))
#' pp[, c("response_id", "block_name", "period", "event", "points_before")]
#'
#' @export
exposure_person_period <- function(x) {
  need <- c("response_id", "flow_order", "routed_in", "displayed", "exit_block",
            "outcome", "shown_points", "design_points")
  if (!all(need %in% names(x))) {
    cli::cli_abort("{.arg x} must be the output of {.fn realised_exposure}.")
  }
  x <- x[order(match(x$response_id, unique(x$response_id)), x$flow_order), ]
  pts <- ifelse(x$routed_in %in% TRUE, x$shown_points, 0)
  pts[is.na(pts)] <- 0
  cum <- stats::ave(pts, x$response_id, FUN = cumsum)
  x$points_before <- cum - pts
  keep <- (x$routed_in %in% TRUE & x$displayed %in% TRUE) | x$exit_block
  out <- x[keep, ]
  out$period <- stats::ave(seq_len(nrow(out)), out$response_id, FUN = seq_along)
  out$event  <- as.integer(out$exit_block & out$outcome == "breakoff")
  out$block_points <- out$design_points
  out
}


# ==============================================================================
# Internals
# ==============================================================================

#' Page number of each question within its block (a block starts on page 1;
#' each page break adds one).
#' @noRd
block_pages <- function(qsf) {
  out <- character(0); nm <- character(0)
  for (b in qsf_block_defs(qsf)) {
    pg <- 1L
    for (el in b$BlockElements %||% list()) {
      if (identical(el$Type, "Page Break")) pg <- pg + 1L
      else if (identical(el$Type, "Question") && !is.null(el$QuestionID)) {
        out <- c(out, as.character(pg)); nm <- c(nm, el$QuestionID)
      }
    }
  }
  stats::setNames(out, nm)
}

#' Map response columns to question, loop iteration and column suffix (the
#' part after the question id or export tag: a choice, matrix row or `TEXT`).
#' @return data.frame(col, qid, iter, suffix)
#' @noRd
exposure_columns <- function(qsf, responses, all_qids) {
  cm <- build_col_map(qsf, responses, all_qids)
  sq <- qsf_elements(qsf, "SQ")
  tags <- stats::setNames(
    vapply(sq, function(p) p$DataExportTag %||% NA_character_, character(1)),
    vapply(sq, function(p) p$QuestionID %||% NA_character_, character(1)))
  user <- attr(responses, "col_map")
  cols <- names(cm)
  suffix <- vapply(cols, function(col) {
    u <- user[[col]]
    if (is.list(u) && !is.null(u$suffix)) return(as.character(u$suffix))
    qid <- cm[[col]]$qid
    s <- col
    if (cm[[col]]$iteration > 0L) s <- sub("^[0-9]+_", "", s)
    for (pre in unique(stats::na.omit(c(qid, tags[qid])))) {
      if (identical(tolower(s), tolower(pre))) return("")
      if (startsWith(tolower(s), paste0(tolower(pre), "_"))) {
        return(substring(s, nchar(pre) + 2L))
      }
    }
    ""
  }, character(1))
  data.frame(
    col    = cols,
    qid    = vapply(cm, `[[`, "", "qid"),
    iter   = vapply(cm, function(m) as.integer(m$iteration), integer(1)),
    suffix = unname(suffix),
    stringsAsFactors = FALSE
  )
}

#' Column for each embedded field used in the flow or display logic.
#' @return named list field -> character vector (NA = blank) or NULL
#' @noRd
embedded_columns <- function(qsf, responses, embedded = NULL) {
  fields <- character(0)
  grab <- function(x) {
    if (!is.list(x)) return(invisible())
    if (identical(x[["LogicType"]], "EmbeddedField") && is.character(x[["LeftOperand"]])) {
      fields <<- c(fields, x[["LeftOperand"]])
    }
    for (el in x) if (is.list(el)) grab(el)
  }
  flow_walk(qsf_flow(qsf)[["Flow"]], function(nd) {
    if (identical(nd$Type, "Branch")) grab(nd[["BranchLogic"]])
    if (identical(nd$Type, "EmbeddedData")) {
      for (e in nd$EmbeddedData) fields <<- c(fields, e$Field %||% character(0))
    }
  })
  for (p in qsf_elements(qsf, "SQ")) grab(p$DisplayLogic)
  fields <- unique(fields)
  rc <- names(responses)
  norm <- function(x) gsub("[^a-z0-9]", "", tolower(x))
  out <- list()
  for (f in fields) {
    col <- if (!is.null(embedded) && f %in% names(embedded)) embedded[[f]]
           else if (f %in% rc) f
           else {
             hit <- rc[tolower(rc) == tolower(f)]
             if (!length(hit)) hit <- rc[norm(rc) == norm(f)]
             if (length(hit)) hit[1] else NA_character_
           }
    if (!is.na(col) && col %in% rc) out[[f]] <- blank_na(responses[[col]])
  }
  out
}

#' Character vector with blanks as NA
#' @noRd
blank_na <- function(v) {
  v <- trimws(as.character(v))
  v[!is.na(v) & !nzchar(v)] <- NA_character_
  v
}

#' Per-question response accessors (answered, selected, entry value), cached.
#' @noRd
exposure_context <- function(responses, cols, payloads, blocks, q, n) {
  cache <- new.env(parent = emptyenv())
  vals <- new.env(parent = emptyenv())
  val <- function(col) {
    v <- vals[[col]]
    if (is.null(v)) { v <- blank_na(responses[[col]]); assign(col, v, envir = vals) }
    v
  }
  by_q <- split(cols, cols$qid)
  loop_block_of <- stats::setNames(
    ifelse(blocks$in_loop[match(q$block, blocks$block_id)] %in% TRUE, q$block, NA_character_),
    names(q$block))

  qcols <- function(qid, iter) {
    d <- by_q[[qid]]
    if (is.null(d)) return(NULL)
    if (is.null(iter)) return(d)
    d[d$iter == iter, , drop = FALSE]
  }
  recode_inv <- function(qid) {
    rv <- payloads[[qid]]$RecodeValues
    if (is.null(rv) || !length(rv)) return(NULL)
    stats::setNames(names(rv), unlist(rv, use.names = FALSE))
  }
  row_inv <- function(qid) {
    rt <- payloads[[qid]]$ChoiceDataExportTags
    if (!is.list(rt) || !length(rt)) return(NULL)
    stats::setNames(names(rt), unlist(rt, use.names = FALSE))
  }
  to_choice <- function(qid, v) {
    inv <- recode_inv(qid)
    if (is.null(inv)) return(v)
    z <- unname(inv[v])
    ifelse(is.na(z), v, z)
  }
  valid_codes <- function(qid) {
    p <- payloads[[qid]]
    unique(c(names(p$Choices), names(p$Answers),
             unlist(p$RecodeValues, use.names = FALSE)))
  }
  # Does each cell hold choice `code`? A cell may hold several codes joined
  # by commas (a multiple-answer question exported to one column). It is
  # split only when every piece is one of the question's choice codes, so a
  # label that itself contains a comma ("this, and that") is never split.
  has_code <- function(qid, v, code) {
    hit <- !is.na(v) & to_choice(qid, v) == code
    multi <- !is.na(v) & !hit & grepl(",", v, fixed = TRUE)
    if (any(multi)) {
      valid <- valid_codes(qid)
      hit[multi] <- vapply(v[multi], function(cell) {
        tk <- trimws(strsplit(cell, ",", fixed = TRUE)[[1]])
        all(tk %in% valid) && code %in% to_choice(qid, tk)
      }, logical(1), USE.NAMES = FALSE)
    }
    hit
  }

  answered <- function(qid, iter = NULL) {
    key <- paste("a", qid, if (is.null(iter)) "*" else iter)
    hit <- cache[[key]]
    if (!is.null(hit)) return(hit)
    d <- qcols(qid, iter)
    res <- if (is.null(d) || !nrow(d)) rep(FALSE, n)
           else Reduce(`|`, lapply(d$col, function(cc) !is.na(val(cc))))
    assign(key, res, envir = cache)
    res
  }
  # iteration a question is read at: its own loop iteration if it is in the
  # loop currently being evaluated (unless the literal asks for any), else
  # 0 for a non-loop question, else any iteration
  iter_for <- function(qid, cur_loop, cur_iter, any = FALSE) {
    lb <- loop_block_of[[qid]] %||% NA_character_
    if (is.na(lb)) return(0L)
    if (!any && identical(lb, cur_loop)) return(as.integer(cur_iter))
    NULL
  }

  has_choice_cols <- function(qid) {
    d <- by_q[[qid]]
    !is.null(d) && any(!grepl("TEXT$", d$suffix, ignore.case = TRUE))
  }
  selected <- function(qid, tail, iter) {
    key <- paste("s", qid, tail, if (is.null(iter)) "*" else iter)
    hit <- cache[[key]]
    if (!is.null(hit)) return(hit)
    d <- qcols(qid, iter)
    # a question with no choice columns (none at all, or only text-entry
    # columns) cannot say what was selected
    res <- if (!has_choice_cols(qid)) rep(NA, n)
           else if (is.null(d) || !nrow(d)) rep(FALSE, n)
           else selected_from_cols(qid, tail, d)
    assign(key, res, envir = cache)
    res
  }
  selected_from_cols <- function(qid, tail, d) {
    main <- d[!grepl("TEXT$", d$suffix, ignore.case = TRUE), , drop = FALSE]
    if (!nrow(main)) return(rep(FALSE, n))
    is_on <- function(cc) { v <- val(cc); !is.na(v) & v != "0" }
    parts <- strsplit(tail, "/", fixed = TRUE)[[1]]
    if (identical(parts[1], "SelectableAnswer") && length(parts) == 2L) {
      return(Reduce(`|`, lapply(main$col, function(cc) {
        has_code(qid, val(cc), parts[2])
      })))
    }
    rinv <- row_inv(qid)
    sfx <- if (is.null(rinv)) main$suffix else ifelse(is.na(rinv[main$suffix]), main$suffix, rinv[main$suffix])
    if (length(parts) == 1L) {
      c1 <- parts[1]
      if (c1 %in% sfx) return(Reduce(`|`, lapply(main$col[sfx == c1], is_on)))
      single <- main$col[sfx == ""]
      # a lone column holds the answer itself, unless its suffix names a
      # choice (one exported column of a multiple-answer question)
      if (!length(single) && nrow(main) == 1L && !sfx %in% valid_codes(qid)) {
        single <- main$col
      }
      if (!length(single)) return(rep(FALSE, n))
      return(Reduce(`|`, lapply(single, function(cc) {
        has_code(qid, val(cc), c1)
      })))
    }
    r <- parts[1]; a <- parts[2]
    cell <- paste0(r, "_", a)
    if (cell %in% sfx) return(Reduce(`|`, lapply(main$col[sfx == cell], is_on)))
    rowc <- main$col[sfx == r]
    if (!length(rowc)) return(rep(FALSE, n))
    Reduce(`|`, lapply(rowc, function(cc) {
      has_code(qid, val(cc), a)
    }))
  }

  # entry value of a question (text or numeric entry), NA = blank; NULL when
  # the question has no response columns
  entry_value <- function(qid, sub, iter) {
    d0 <- by_q[[qid]]
    if (is.null(d0)) return(NULL)
    d <- qcols(qid, iter)
    if (is.null(d) || !nrow(d)) return(rep(NA_character_, n))
    pick <- if (nzchar(sub) && sub %in% d$suffix) d$col[d$suffix == sub]
            else if (any(d$suffix %in% c("", "TEXT"))) d$col[d$suffix %in% c("", "TEXT")]
            else d$col
    v <- rep(NA_character_, n)
    for (cc in pick) { x <- val(cc); v[is.na(v)] <- x[is.na(v)] }
    v
  }

  # numeric value of a question's answer (recode), for loop drivers
  numeric_answer <- function(qid) {
    d <- qcols(qid, 0L)
    if (is.null(d) || !nrow(d)) return(rep(NA_real_, n))
    main <- d[!grepl("TEXT$", d$suffix, ignore.case = TRUE), , drop = FALSE]
    if (!nrow(main)) return(rep(NA_real_, n))
    v <- rep(NA_character_, n)
    for (cc in main$col) { x <- val(cc); v[is.na(v)] <- x[is.na(v)] }
    suppressWarnings(as.numeric(v))
  }

  list(answered = answered, answered_any = function(qid) answered(qid, NULL),
       selected = selected, entry_value = entry_value, numeric_answer = numeric_answer,
       iter_for = iter_for, has_cols = function(qid) !is.null(by_q[[qid]]),
       iters_of = function(qids) sort(unique(unlist(lapply(qids, function(x) by_q[[x]]$iter)))),
       payloads = payloads, n = n)
}

#' Map a last-seen column (ordinal, block id, block name or QID) to a block
#' ordinal; NA where unrecognised.
#' @noRd
furthest_from_column <- function(v, blocks, q_block) {
  v <- trimws(as.character(v))
  out <- rep(NA_real_, length(v))
  fill <- function(m) { i <- is.na(out) & !is.na(m); out[i] <<- m[i] }
  # exact identifiers first, so a block named "2" is that block, not block 2
  fill(match(v, blocks$block_id))
  fill(match(v, blocks$block_name))
  fill(match(unname(q_block[v]), blocks$block_id))
  num <- suppressWarnings(as.numeric(v))
  ok <- !is.na(num) & num == round(num) & num >= 1 & num <= nrow(blocks)
  fill(ifelse(ok, num, NA_real_))
  out
}

#' Vectorised Qualtrics comparison. `x` is a character vector (NA = empty).
#' Mirrors eval_branch_op(): numeric when both sides parse as numbers, else
#' string; an empty value is only "not equal". Unknown operator -> NA.
#' @noRd
compare_vec <- function(op, x, rhs) {
  rhs <- as.character(rhs %||% "")
  xn <- suppressWarnings(as.numeric(x)); rn <- suppressWarnings(as.numeric(rhs))
  num <- !is.na(xn) & !is.na(rn)
  empty <- is.na(x)
  res <- switch(op,
    EqualTo            = ifelse(num, xn == rn, !empty & x == rhs),
    NotEqualTo         = ifelse(num, xn != rn, empty | x != rhs),
    GreaterThan        = num & xn >  rn,
    GreaterThanOrEqual = num & xn >= rn,
    LessThan           = num & xn <  rn,
    LessThanOrEqual    = num & xn <= rn,
    Contains           = !empty & grepl(rhs, x, fixed = TRUE),
    DoesNotContain     = empty | !grepl(rhs, x, fixed = TRUE),
    Empty              = empty,
    NotEmpty           = !empty,
    rep(NA, length(x)))
  res[is.na(res) & op %in% c("EqualTo", "GreaterThan", "GreaterThanOrEqual",
                             "LessThan", "LessThanOrEqual")] <- FALSE
  as.logical(res)
}

#' Evaluate a Qualtrics logic tree (BranchLogic or DisplayLogic) for every
#' respondent, in three-valued logic: NA where it cannot be settled.
#' `env` carries the walk's state (shown, embedded values) and the current
#' loop block and iteration.
#' @noRd
eval_logic_vec <- function(lg, env) {
  n <- env$ctx$n
  gkeys <- setdiff(names(lg), c("Type", "inPage"))
  if (!length(gkeys)) return(rep(TRUE, n))
  vals <- vector("list", length(gkeys))
  for (gi in seq_along(gkeys)) {
    g <- lg[[gkeys[gi]]]
    lits <- lapply(setdiff(names(g), "Type"), function(lk) g[[lk]])
    # And binds before Or within a group (see combine_literals())
    vals[[gi]] <- if (!length(lits)) rep(TRUE, n) else combine_literals(
      lapply(lits, eval_literal_vec, env = env),
      vapply(lits, function(l) l$Conjuction %||% NA_character_, character(1)))
  }
  types <- vapply(gkeys, function(k) lg[[k]]$Type %||% NA_character_, character(1))
  # "AndIf" groups bind before "ElseIf" groups (see combine_groups())
  combine_groups(vals, unname(types))
}

#' @noRd
eval_literal_vec <- function(lit, env) {
  ctx <- env$ctx; n <- ctx$n
  lt <- lit$LogicType %||% "Question"
  op <- lit$Operator %||% "Selected"
  if (identical(lt, "Question")) {
    qid <- lit$QuestionID %||% sub("^q://(QID[0-9]+).*", "\\1", lit$LeftOperand %||% "")
    any_iter <- grepl(",any$", lit$LoopAndMergeLoops %||% "")
    it <- ctx$iter_for(qid, env$loop, env$iter, any = any_iter)
    if (op %in% c("Displayed", "NotDisplayed")) {
      d <- env$get_shown(qid, it)
      return(if (identical(op, "NotDisplayed")) !d else d)
    }
    if (op %in% c("Selected", "NotSelected")) {
      tail <- sub("^q://QID[0-9]+/SelectableChoice/", "",
                  lit$ChoiceLocator %||% lit$LeftOperand %||% "")
      tail <- sub("^q://QID[0-9]+/", "", tail)
      tail <- sub("^SelectableChoice/", "", tail)
      hit <- ctx$selected(qid, tail, it)
      return(if (identical(op, "NotSelected")) !hit else hit)
    }
    loc <- lit$LeftOperand %||% lit$ChoiceLocator %||% ""
    if (grepl("/(ChoiceTextEntryValue|ChoiceNumericEntryValue)", loc)) {
      sub_ <- sub("^q://QID[0-9]+/Choice(Text|Numeric)EntryValue/?", "", loc)
      sub_ <- sub("/.*$", "", sub_)
      v <- ctx$entry_value(qid, sub_, it)
      if (is.null(v)) return(rep(NA, n))
      return(compare_vec(op, v, lit$RightOperand))
    }
    return(rep(NA, n))
  }
  if (identical(lt, "EmbeddedField")) {
    f <- lit$LeftOperand %||% ""
    v <- env$get_emb(f)
    res <- compare_vec(op, v$value, lit$RightOperand)
    res[!v$known] <- NA
    return(res)
  }
  if (identical(lt, "LoopAndMerge") &&
      identical(lit$RightOperand %||% "", "lm://CurrentLoop") &&
      op %in% c("EqualTo", "NotEqualTo")) {
    parts <- strsplit(lit$LeftOperand %||% "", ",", fixed = TRUE)[[1]]
    if (length(parts) == 2L && identical(parts[1], env$loop %||% "")) {
      eq <- identical(as.character(env$iter), parts[2])
      return(rep(if (identical(op, "EqualTo")) eq else !eq, n))
    }
    return(rep(NA, n))
  }
  rep(NA, n)
}

#' Does a flow-node list contain a block or an EndSurvey (anywhere inside)?
#' @noRd
flow_contents <- function(nodes) {
  blocks <- character(0); ends <- FALSE
  flow_walk(nodes, function(nd) {
    if (nd$Type %in% c("Standard", "Block") && !is.null(nd$ID)) blocks <<- c(blocks, nd$ID)
    if (identical(nd$Type, "EndSurvey")) ends <<- TRUE
  })
  list(blocks = unique(blocks), ends = ends)
}

#' Loop & Merge iteration ids for a block, and the locator kind.
#' @noRd
loop_spec <- function(qsf, blocks, k) {
  defs <- qsf_block_defs(qsf)
  ids <- vapply(defs, function(b) b$ID %||% NA_character_, character(1))
  b <- defs[[match(blocks$block_id[k], ids)]]
  lo <- b$Options$LoopingOptions %||% list()
  loc <- lo$Locator %||% ""
  driver <- lo$QID %||% NA_character_
  kind <- if (grepl("MergeOnNumericResponse", loc)) "numeric"
          else if (grepl("SelectedChoices", loc)) "selected"
          else if (grepl("UnselectedChoices", loc)) "unselected"
          else if (grepl("DisplayedChoices", loc)) "displayed"
          else "static"
  lmax <- blocks$loop_max[k]
  # Export columns number loops by position in the loop field (1, 2, ...),
  # not by choice id, so a choice-driven loop keeps both: iteration j is
  # the j-th choice of the driving question.
  choice_ids <- if (kind %in% c("selected", "unselected", "displayed") && !is.na(driver))
                  names(qsf_elements_payload(qsf, driver)$Choices %||% list())
                else character(0)
  ids_all <- if (identical(kind, "numeric") && !is.na(lmax)) as.character(seq_len(lmax))
             else if (length(choice_ids)) as.character(seq_along(choice_ids))
             else as.character(seq_along(lo$Static %||% list()))
  rnd <- lo$Randomization %||% "None"
  randomised <- !(is.character(rnd) && rnd %in% c("None", ""))
  # a randomised loop may present only a subset of its eligible iterations
  lim <- lo[grepl("subset|limit|present", names(lo), ignore.case = TRUE)]
  limited <- randomised &&
    any(!is.na(suppressWarnings(as.numeric(unlist(lim, use.names = FALSE)))))
  list(kind = kind, driver = driver, ids = ids_all, max = lmax, choice_ids = choice_ids,
       randomised = randomised, limited = limited)
}

#' @noRd
qsf_elements_payload <- function(qsf, qid) {
  for (p in qsf_elements(qsf, "SQ")) if (identical(p$QuestionID, qid)) return(p)
  list()
}

#' Walk the survey flow for all respondents at once, evaluating branch logic
#' and display logic in flow order.
#' @noRd
exposure_walk <- function(qsf, blocks, ctx, emb, ans_block, last_ans, fin,
                          loop_iterations, furthest_ord) {
  n <- ctx$n; nb <- nrow(blocks)
  st <- new.env(parent = emptyenv())
  st$alive <- rep(TRUE, n)
  st$ended <- rep(FALSE, n)
  st$ended_early <- rep(FALSE, n)
  st$end_pos <- rep(Inf, n)
  st$routed <- matrix(FALSE, n, nb)
  st$unres_branch <- integer(n)
  # per respondent and block: loop iterations not recoverable (see
  # enter_block); counted later only for blocks the respondent reached
  st$unres_loop <- matrix(FALSE, n, nb)
  st$conflicts <- integer(n)
  st$pos <- 0L
  st$shown <- list()       # qid -> logical vector, or matrix n x iteration ids
  st$unres <- list()       # qid -> logical vector / matrix: fell back to answered
  st$iters <- list()       # block id -> logical matrix n x iteration ids
  st$loop_random <- list()
  st$warned_rand <- FALSE
  # embedded values: column values where the export has the field
  st$emb_val <- lapply(emb, identity)
  st$emb_known <- lapply(emb, function(v) rep(TRUE, n))
  st$emb_col <- emb                # exported (final) values, kept for restores
  st$emb_has_col <- names(emb)

  env <- list(ctx = ctx, loop = NULL, iter = NULL)
  env$get_shown <- function(qid, it) {
    s <- st$shown[[qid]]
    if (is.null(s)) return(rep(FALSE, n))
    if (is.matrix(s)) {
      if (is.null(it)) return(rowSums(s) > 0)
      j <- as.character(it)
      if (!j %in% colnames(s)) return(rep(FALSE, n))
      return(s[, j])
    }
    s
  }
  env$get_emb <- function(f) {
    v <- st$emb_val[[f]]
    if (is.null(v)) return(list(value = rep(NA_character_, n), known = rep(FALSE, n)))
    list(value = v, known = st$emb_known[[f]])
  }

  eval_q <- function(qid, mask, e) {
    dl <- ctx$payloads[[qid]]$DisplayLogic
    if (is.null(dl)) return(list(shown = mask, unres = rep(FALSE, n)))
    v <- eval_logic_vec(dl, e)
    un <- is.na(v) & mask
    it <- if (is.null(e$iter)) NULL else as.integer(e$iter)
    if (any(un)) {
      a <- ctx$answered(qid, if (is.null(e$loop)) 0L else it)
      v[un] <- a[un]
    }
    list(shown = mask & v %in% TRUE, unres = un)
  }

  enter_block <- function(k, mask) {
    act <- mask & st$alive
    ev <- ans_block[, k]
    st$conflicts <- st$conflicts + as.integer(ev & !act & !st$routed[, k])
    act <- act | ev
    st$routed[, k] <- st$routed[, k] | act
    st$pos <- max(st$pos, k)
    qs <- blocks$question_ids[[k]]
    bid <- blocks$block_id[k]
    if (!isTRUE(blocks$in_loop[k])) {
      for (qid in qs) {
        r <- eval_q(qid, act, env)
        st$shown[[qid]] <- if (is.null(st$shown[[qid]])) r$shown else st$shown[[qid]] | r$shown
        st$unres[[qid]] <- if (is.null(st$unres[[qid]])) r$unres else st$unres[[qid]] | r$unres
      }
      return(invisible())
    }
    sp <- loop_spec(qsf, blocks, k)
    ids <- sp$ids
    extra <- setdiff(as.character(setdiff(ctx$iters_of(qs), 0L)), ids)
    ids <- c(ids, extra[order(as.integer(extra))])
    if (!length(ids)) {
      # no loop size in the QSF and no iteration columns: nothing to count
      st$unres_loop[, k] <- st$unres_loop[, k] | act
      none <- matrix(FALSE, n, 0L)
      merge_iters(bid, none)
      for (qid in qs) merge_q(qid, none, none)
      return(invisible())
    }
    obs <- vapply(ids, function(j) {
      Reduce(`|`, lapply(qs, function(x) ctx$answered(x, as.integer(j))), init = rep(FALSE, n))
    }, logical(n))
    if (is.null(dim(obs))) obs <- matrix(obs, nrow = n, dimnames = list(NULL, ids))
    # observed: every iteration up to the last one answered. A randomised
    # loop is not shown in export order, so only answered iterations count.
    last_obs <- apply(obs, 1, function(r) if (any(r)) max(which(r)) else 0L)
    obs_fill <- if (sp$randomised) obs else outer(last_obs, seq_along(ids), `>=`)
    drv <- matrix(NA, n, length(ids), dimnames = list(NULL, ids))
    # the driver gives the eligible iterations; a randomised loop that shows
    # only a subset of them presents an unknown number, so it is left to the
    # answers
    use_driver <- identical(loop_iterations, "driver") && !sp$limited
    if (use_driver && !is.na(sp$driver) && ctx$has_cols(sp$driver)) {
      if (identical(sp$kind, "numeric")) {
        cnt <- floor(ctx$numeric_answer(sp$driver))
        cnt <- pmin(pmax(cnt, 0), length(ids))
        for (j in seq_along(ids)) drv[, j] <- ifelse(is.na(cnt), NA, j <= cnt)
      } else if (sp$kind %in% c("selected", "unselected")) {
        any_ans <- ctx$answered(sp$driver, 0L)
        for (j in seq_along(sp$choice_ids)) {
          s <- ctx$selected(sp$driver, sp$choice_ids[j], 0L)
          if (identical(sp$kind, "unselected")) s <- !s
          drv[, j] <- ifelse(any_ans, s, NA)
        }
      }
    }
    if (identical(sp$kind, "static") && is.na(sp$driver) && !sp$randomised &&
        identical(loop_iterations, "driver")) {
      drv[, ] <- TRUE
    }
    if (sp$randomised) st$unres_loop[, k] <- st$unres_loop[, k] | (act & is.na(drv[, 1L]))
    if (sp$limited) st$unres_loop[, k] <- st$unres_loop[, k] | act
    inm <- ifelse(is.na(drv), obs_fill, drv | obs)
    inm <- matrix(as.logical(inm), n, length(ids), dimnames = list(NULL, ids))
    inm <- inm & act
    merge_iters(bid, inm)
    st$loop_random[[bid]] <- sp$randomised
    for (qid in qs) {
      sh <- matrix(FALSE, n, length(ids), dimnames = list(NULL, ids))
      un <- sh
      for (j in seq_along(ids)) {
        m <- inm[, j]
        if (!any(m)) next
        e <- env; e$loop <- bid; e$iter <- ids[j]
        r <- eval_q(qid, m, e)
        sh[, j] <- r$shown; un[, j] <- r$unres
      }
      # stored at once, so a later question's Displayed() sees this one
      merge_q(qid, sh, un)
    }
  }

  # A block can appear more than once in the flow: occurrences are combined,
  # so a later (untaken) one never overwrites an earlier one.
  or_m <- function(a, b) if (is.null(a) || !identical(dim(a), dim(b))) b else a | b
  merge_iters <- function(bid, inm) st$iters[[bid]] <- or_m(st$iters[[bid]], inm)
  merge_q <- function(qid, sh, un) {
    st$shown[[qid]] <- or_m(st$shown[[qid]], sh)
    st$unres[[qid]] <- or_m(st$unres[[qid]], un)
  }

  set_embedded <- function(nd, mask) {
    act <- mask & st$alive
    for (e in nd$EmbeddedData %||% list()) {
      f <- e$Field %||% ""
      if (!nzchar(f)) next
      val <- e$Value %||% ""
      has_col <- f %in% st$emb_has_col
      # Assignments apply in flow order, from this point on. A field the
      # export has starts at its column (its final value), so a field set
      # more than once is read as it stood at each branch:
      # - a fixed value (Custom, including an empty one) sets that value;
      # - a piped or computed value (${...}, $e{...}) cannot be evaluated: an
      #   exported field goes back to its column value, any other field
      #   becomes unknown;
      # - a declaration with no value (set from a panel or URL) changes
      #   nothing.
      if (!is.character(val) || grepl("\\$[A-Za-z]*\\{", val)) {
        if (has_col) {
          st$emb_val[[f]][act] <- st$emb_col[[f]][act]
          st$emb_known[[f]][act] <- TRUE
        } else if (!is.null(st$emb_val[[f]])) {
          st$emb_known[[f]][act] <- FALSE
        }
        next
      }
      if (!nzchar(val) && !identical(e$Type, "Custom")) next
      if (is.null(st$emb_val[[f]])) {
        st$emb_val[[f]] <- rep(NA_character_, n)
        st$emb_known[[f]] <- rep(FALSE, n)
      }
      st$emb_val[[f]][act] <- if (nzchar(val)) val else NA_character_
      st$emb_known[[f]][act] <- TRUE
    }
  }

  walk <- function(nodes, mask) {
    for (nd in nodes) {
      if (!is.list(nd)) next
      tp <- nd$Type %||% ""
      if (tp %in% c("Standard", "Block")) {
        k <- match(nd$ID %||% "", blocks$block_id)
        if (!is.na(k)) enter_block(k, mask)
      } else if (identical(tp, "EmbeddedData")) {
        set_embedded(nd, mask)
      } else if (identical(tp, "EndSurvey")) {
        act <- mask & st$alive
        st$ended[act] <- TRUE
        st$end_pos[act] <- st$pos
        if (st$pos < nb) st$ended_early[act] <- TRUE
        st$alive[act] <- FALSE
      } else if (identical(tp, "Branch")) {
        sub <- nd[["Flow"]] %||% list()
        cond <- eval_logic_vec(nd[["BranchLogic"]] %||% list(), env)
        act <- mask & st$alive
        un <- is.na(cond) & act
        if (any(un)) {
          fc <- flow_contents(sub)
          ks <- match(fc$blocks, blocks$block_id)
          ks <- ks[!is.na(ks)]
          in_sub <- if (length(ks)) rowSums(ans_block[, ks, drop = FALSE]) > 0 else rep(FALSE, n)
          ends <- fc$ends & fin %in% TRUE & !(last_ans > st$pos)
          cond[un] <- (in_sub | ends)[un]
          # count only branches the respondent got past (before their exit)
          cnt <- un & furthest_ord > st$pos
          if (length(ks) || fc$ends) st$unres_branch[cnt] <- st$unres_branch[cnt] + 1L
        }
        cond[is.na(cond)] <- FALSE
        walk(sub, mask & cond)
      } else if (tp %in% c("Group", "Authenticator")) {
        walk(nd[["Flow"]] %||% list(), mask)
      } else if (identical(tp, "BlockRandomizer")) {
        if (!st$warned_rand && flow_has_blocks(nd[["Flow"]] %||% list())) {
          cli::cli_warn("BlockRandomizer in the flow: every sub-block is treated as shown, in survey order.")
          st$warned_rand <- TRUE
        }
        walk(nd[["Flow"]] %||% list(), mask)
      }
    }
  }

  walk(qsf_flow(qsf)[["Flow"]], rep(TRUE, n))
  as.list(st)
}

#' Shown counts for block k.
#' @noRd
assemble_block <- function(k, blocks, walk, q, pages, rr, outcome, furthest_ord, ctx, n) {
  qs <- blocks$question_ids[[k]]
  bid <- blocks$block_id[k]
  pts <- numeric(n); items <- integer(n); ritems <- integer(n); unres <- integer(n)
  hid <- integer(n)
  pg_list <- list()
  add_page <- function(key, s) {
    pg_list[[key]] <<- if (is.null(pg_list[[key]])) s else pg_list[[key]] | s
  }
  if (!isTRUE(blocks$in_loop[k])) {
    for (qid in qs) {
      s <- (walk$shown[[qid]] %||% rep(FALSE, n)) & rr
      pts <- pts + q$gfs[[qid]] * s
      vis <- q$visible[[qid]]
      items <- items + as.integer(s) * vis
      ritems <- ritems + as.integer(s) * q$responsive[[qid]] * vis
      hid <- hid + as.integer(s) * !vis
      unres <- unres + as.integer((walk$unres[[qid]] %||% rep(FALSE, n)) & rr)
      if (isTRUE(q$visible[[qid]])) add_page(pages[[qid]] %||% "1", s)
    }
    npg <- if (length(pg_list)) as.integer(Reduce(`+`, lapply(pg_list, as.integer))) else integer(n)
    return(list(shown_points = pts, shown_items = items, shown_response_items = ritems,
                shown_pages = npg, unresolved_items = unres, iterations = NA_integer_,
                shown_hidden_items = hid))
  }
  inm <- walk$iters[[bid]]
  if (is.null(inm)) {
    z <- integer(n)
    return(list(shown_points = numeric(n), shown_items = z, shown_response_items = z,
                shown_pages = z, unresolved_items = z, iterations = z,
                shown_hidden_items = z))
  }
  ids <- colnames(inm)
  # exit block of a break-off: iterations up to the last one answered (a
  # randomised loop: only the iterations answered, as its order is unknown)
  exit_here <- outcome == "breakoff" & is.finite(furthest_ord) & furthest_ord == k
  if (any(exit_here) && length(ids)) {
    obs <- vapply(ids, function(j) Reduce(`|`, lapply(qs, function(x)
      ctx$answered(x, as.integer(j))), init = rep(FALSE, n)), logical(n))
    if (is.null(dim(obs))) obs <- matrix(obs, nrow = n)
    if (isTRUE(walk$loop_random[[bid]])) {
      lim <- obs
    } else {
      last_obs <- apply(obs, 1, function(r) if (any(r)) max(which(r)) else 1L)
      lim <- outer(last_obs, seq_along(ids), `>=`)
    }
    inm[exit_here, ] <- inm[exit_here, , drop = FALSE] & lim[exit_here, , drop = FALSE]
  }
  inm <- inm & rr
  npg <- integer(n)
  for (j in seq_along(ids)) {
    pg_list <- list()
    for (qid in qs) {
      s <- walk$shown[[qid]][, j] & inm[, j]
      pts <- pts + q$gfs[[qid]] * s
      vis <- q$visible[[qid]]
      items <- items + as.integer(s) * vis
      ritems <- ritems + as.integer(s) * q$responsive[[qid]] * vis
      hid <- hid + as.integer(s) * !vis
      unres <- unres + as.integer(walk$unres[[qid]][, j] & inm[, j])
      if (isTRUE(q$visible[[qid]])) add_page(pages[[qid]] %||% "1", s)
    }
    if (length(pg_list)) npg <- npg + as.integer(Reduce(`+`, lapply(pg_list, as.integer)))
  }
  list(shown_points = pts, shown_items = items, shown_response_items = ritems,
       shown_pages = npg, unresolved_items = unres,
       iterations = as.integer(rowSums(inm)), shown_hidden_items = hid)
}
