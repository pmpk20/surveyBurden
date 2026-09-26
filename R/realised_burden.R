#' Realised response burden from observed responses
#'
#' Scores the questions each respondent actually answered, using the GfS+
#' scheme and the survey's structure from the QSF. Unlike [respondent_burden()],
#' which predicts burden from structural paths, this function measures it from
#' data: every respondent gets a unique score reflecting their actual route
#' through the survey.
#'
#' @param qsf A `qsf_raw` object, a path to a `.qsf` file, or a survey id
#'   accepted by [fetch_qsf()].
#' @param responses A data frame of response data. Columns must be mappable to
#'   question ids via one of these strategies (tried in order):
#'   1. Column names match question ids directly (`QID15`, `QID15_1`).
#'   2. Column names match `DataExportTag` values from the QSF (`Q15`,
#'      `travel_mode_1`).
#'   3. A `col_map` attribute on the data frame maps column names to QIDs
#'      (set by a future `read_responses()` helper from the Qualtrics CSV
#'      ImportId row).
#'
#'   The recommended way to obtain this data frame is
#'   `qualtRics::fetch_survey(survey_id, label = FALSE, convert = FALSE,
#'   add_column_map = FALSE)`.
#' @param scheme A [gfs_scheme()] list.
#' @param words_per_line How many words fit on one rendered line, used only when
#'   scoring descriptive-text questions. `NULL` (default) uses
#'   `scheme$words_per_line` (12). A single number applies to all respondents.
#'   A numeric vector of length `nrow(responses)` gives per-respondent values,
#'   allowing the user to reflect device differences (e.g., phone vs desktop).
#'   The user is responsible for mapping device metadata to appropriate values;
#'   the package does not assume any device-to-value mapping.
#' @param id_col Name of the respondent-id column. Auto-detected from
#'   `"ResponseId"`, `"response_id"`, or the first column whose values are all
#'   unique. Pass explicitly to override.
#'
#' @return A [tibble][tibble::tibble] with one row per respondent:
#'   \describe{
#'     \item{`response_id`}{Respondent identifier (from `id_col`).}
#'     \item{`finished`}{Logical: did the respondent reach the end? Read from
#'       a `Finished` column coded `1`/`0`, `TRUE`/`FALSE` or yes/no (any
#'       case). `NA` means the status is unknown (no such column, a blank, or
#'       an unrecognised value), not that the respondent did not finish.}
#'     \item{`furthest_block`}{Integer ordinal of the last block in which the
#'       respondent answered at least one question.}
#'     \item{`n_questions_answered`}{Count of distinct questions with at least
#'       one non-blank response column.}
#'     \item{`realised_points`}{Sum of GfS points for answered questions; loop
#'       questions scored once per answered iteration.}
#'     \item{`realised_minutes`}{`realised_points / points_per_minute`.}
#'     \item{`predicted_points`}{Structural-path prediction for comparison (from
#'       [respondent_burden()] logic, using inferred loop counts and visit
#'       flags).}
#'     \item{`predicted_minutes`}{`predicted_points / points_per_minute`.}
#'     \item{`words_per_line`}{The words-per-line value used for each
#'       respondent's descriptive-text scoring.}
#'     \item{`n_unmapped_cols`}{Number of response columns that could not be
#'       mapped to any question in the QSF.}
#'   }
#'
#' @section Recommended Qualtrics export:
#' Via the API (cleanest):
#' ```
#' responses <- qualtRics::fetch_survey(
#'   surveyID   = "SV_...",
#'   label      = FALSE,    # numeric recode values, not choice text
#'   convert    = FALSE,    # keep raw strings, don't coerce
#'   force_request = TRUE   # bypass cache
#' )
#' qsf <- fetch_qsf("SV_...")
#' rb  <- realised_burden(qsf, responses)
#' ```
#'
#' Via CSV download: Data & Analysis > Export & Import > Export Data > CSV.
#' Tick "Use numeric values". Read with
#' `read.csv("file.csv", check.names = FALSE)` and pass directly. The column
#' names will be the question export tags; the function maps them via the QSF.
#'
#' @examples
#' \donttest{
#' qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
#'                          package = "surveyBurden")
#' # Simulate response data with QID-based column names
#' responses <- data.frame(
#'   ResponseId = paste0("R_", 1:5),
#'   Finished   = c(1, 1, 1, 0, 0),
#'   QID1       = rep(NA, 5),          # descriptive text, no response
#'   QID2       = c("1", "2", "1", "1", NA),
#'   QID3       = c("2", "1", "3", NA, NA),
#'   stringsAsFactors = FALSE
#' )
#' rb <- realised_burden(qsf_path, responses)
#' rb[, c("response_id", "finished", "realised_points", "predicted_points")]
#' }
#'
#' @export
realised_burden <- function(qsf, responses, scheme = gfs_scheme(),
                            words_per_line = NULL, id_col = NULL) {
  if (!inherits(qsf, "qsf_raw")) qsf <- read_qsf(qsf)

  n_resp <- nrow(responses)

  # ---- resolve words_per_line ------------------------------------------------
  if (is.null(words_per_line)) {
    wpl_vec <- rep(scheme$words_per_line, n_resp)
  } else if (length(words_per_line) == 1L) {
    wpl_vec <- rep(words_per_line, n_resp)
  } else if (length(words_per_line) == n_resp) {
    wpl_vec <- words_per_line
  } else {
    cli::cli_abort(
      "{.arg words_per_line} must be {.code NULL}, a single number, or a vector of length {n_resp} (one per respondent)."
    )
  }

  catalogue <- parse_qsf(qsf)
  blocks    <- resolve_live_blocks(qsf)
  ppm       <- scheme$points_per_minute

  # Score once per unique wpl value
  unique_wpl <- sort(unique(wpl_vec))
  scored_by_wpl <- list()
  for (wv in unique_wpl) {
    w_tmp <- scheme
    w_tmp$words_per_line <- wv
    sc <- score_burden(catalogue, w_tmp)
    scored_by_wpl[[as.character(wv)]] <- stats::setNames(sc$gfs_points, sc$question_id)
  }
  resp_wpl_key <- as.character(wpl_vec)

  # Use the default-wpl scoring for structural metadata
  scored <- score_burden(catalogue, scheme)
  q_block_id  <- stats::setNames(scored$block_id, scored$question_id)
  q_block_ord <- stats::setNames(
    blocks$flow_order[match(scored$block_id, blocks$block_id)],
    scored$question_id
  )
  q_in_loop <- stats::setNames(scored$in_loop, scored$question_id)
  all_qids  <- scored$question_id

  # ---- column -> QID mapping -------------------------------------------------
  col_map <- build_col_map(qsf, responses, all_qids)
  n_unmapped <- attr(col_map, "n_unmapped") %||% 0L

  # ---- respondent ID and finished status -------------------------------------
  id_col  <- resolve_id_col(responses, id_col)
  resp_id <- if (!is.null(id_col)) responses[[id_col]] else seq_len(nrow(responses))
  fin     <- detect_finished(responses)

  # ---- per-respondent: which QIDs answered, loop iteration counts ------------
  realised <- numeric(n_resp)
  n_answered <- integer(n_resp)
  farthest   <- integer(n_resp)

  # precompute non-blank matrix per mapped column
  mapped_cols <- names(col_map)
  nb <- vapply(mapped_cols, function(col) {
    v <- responses[[col]]
    !is.na(v) & nzchar(trimws(as.character(v)))
  }, logical(n_resp))
  if (is.null(dim(nb))) nb <- matrix(nb, nrow = n_resp, ncol = length(mapped_cols))
  colnames(nb) <- mapped_cols

  # group columns by QID, separating loop iterations
  qid_cols <- split(mapped_cols, vapply(mapped_cols, function(c) col_map[[c]]$qid, character(1)))

  for (qid in names(qid_cols)) {
    cols <- qid_cols[[qid]]
    ord  <- q_block_ord[[qid]]

    if (isTRUE(q_in_loop[[qid]])) {
      iters <- vapply(cols, function(c) col_map[[c]]$iteration, integer(1))
      iter_groups <- split(cols, iters)
      for (ig in iter_groups) {
        if (length(ig) == 1L) {
          ans <- nb[, ig]
        } else {
          ans <- rowSums(nb[, ig, drop = FALSE]) > 0
        }
        for (wv in unique_wpl) {
          mask <- ans & (resp_wpl_key == as.character(wv))
          realised[mask] <- realised[mask] + scored_by_wpl[[as.character(wv)]][[qid]]
        }
        n_answered <- n_answered + as.integer(ans)
        farthest   <- ifelse(ans & !is.na(ord) & ord > farthest, ord, farthest)
      }
    } else {
      if (length(cols) == 1L) {
        ans <- nb[, cols]
      } else {
        ans <- rowSums(nb[, cols, drop = FALSE]) > 0
      }
      for (wv in unique_wpl) {
        mask <- ans & (resp_wpl_key == as.character(wv))
        realised[mask] <- realised[mask] + scored_by_wpl[[as.character(wv)]][[qid]]
      }
      n_answered <- n_answered + as.integer(ans)
      farthest   <- ifelse(ans & !is.na(ord) & ord > farthest, ord, farthest)
    }
  }

  # ---- predicted burden (structural, for comparison) -------------------------
  pred <- predict_from_responses(qsf, responses, col_map, blocks, scheme)

  tibble::tibble(
    response_id          = resp_id,
    finished             = fin,
    furthest_block       = farthest,
    n_questions_answered = n_answered,
    realised_points      = realised,
    realised_minutes     = realised / ppm,
    predicted_points     = pred$points,
    predicted_minutes    = pred$points / ppm,
    words_per_line       = wpl_vec,
    n_unmapped_cols      = rep(n_unmapped, n_resp)
  )
}


# ==============================================================================
# Column-to-QID mapping
# ==============================================================================

#' Map response data columns to question ids
#'
#' Tries three strategies in order:
#' 1. Direct QID-based column names (`QID15`, `QID15_1`)
#' 2. ExportTag-based names from the QSF (`Q15`, `travel_mode_1`)
#' 3. A `col_map` attribute on the data frame (set by a helper or user)
#'
#' @return A named list: each element is named by a response column and contains
#'   `list(qid, iteration)` where `iteration` is 0L for non-loop questions.
#' @noRd
build_col_map <- function(qsf, responses, all_qids) {
  resp_cols <- names(responses)

  # extract export tags from QSF
  sq_payloads <- qsf_elements(qsf, "SQ")
  export_tags <- stats::setNames(
    vapply(sq_payloads, function(p) p$DataExportTag %||% NA_character_, character(1)),
    vapply(sq_payloads, function(p) p$QuestionID %||% NA_character_, character(1))
  )
  export_tags <- export_tags[!is.na(names(export_tags)) & !is.na(export_tags)]
  tag_to_qid <- stats::setNames(names(export_tags), export_tags)
  # case-insensitive fallback (first tag wins for each lowered form)
  tag_to_qid_lower <- tag_to_qid[!duplicated(tolower(names(tag_to_qid)))]
  names(tag_to_qid_lower) <- tolower(names(tag_to_qid_lower))

  # check for user-supplied col_map attribute
  user_map <- attr(responses, "col_map")

  result <- list()
  mapped <- 0L
  unmapped <- 0L

  # system/metadata columns to skip
  skip_cols <- c("StartDate", "EndDate", "Status", "IPAddress", "Progress",
                 "Duration (in seconds)", "Finished", "RecordedDate",
                 "ResponseId", "RecipientLastName", "RecipientFirstName",
                 "RecipientEmail", "ExternalReference", "LocationLatitude",
                 "LocationLongitude", "DistributionChannel", "UserLanguage",
                 "response_id", "finished", "status")

  for (col in resp_cols) {
    if (tolower(col) %in% tolower(skip_cols)) next

    mapping <- NULL

    # strategy 1: user-supplied attribute
    if (!is.null(user_map) && col %in% names(user_map)) {
      qid <- user_map[[col]]
      if (qid %in% all_qids) {
        mapping <- list(qid = qid, iteration = 0L)
      }
    }

    # strategy 2: QID-based column name
    if (is.null(mapping)) {
      mapping <- parse_qid_column(col, all_qids)
    }

    # strategy 3: ExportTag-based column name (exact then case-insensitive)
    if (is.null(mapping)) {
      mapping <- parse_tag_column(col, tag_to_qid, all_qids)
    }
    if (is.null(mapping)) {
      mapping <- parse_tag_column(tolower(col), tag_to_qid_lower, all_qids)
    }

    if (!is.null(mapping)) {
      result[[col]] <- mapping
      mapped <- mapped + 1L
    } else {
      unmapped <- unmapped + 1L
    }
  }

  if (mapped == 0L) {
    cli::cli_abort(c(
      "No response columns could be mapped to question ids in the QSF.",
      i = "Column names should match QIDs ({.code QID15}, {.code QID15_1}) or export tags ({.code Q15}).",
      i = "Use {.code qualtRics::fetch_survey(survey_id, label = FALSE, convert = FALSE)} for clean column names."
    ))
  }

  attr(result, "n_unmapped") <- unmapped
  result
}


#' Try to parse a column name as QID-based: QID15, QID15_1, QID15_1_TEXT, etc.
#' For loop iterations: pattern is #iter_QID or QID_iter_suffix
#' @noRd
parse_qid_column <- function(col, all_qids) {
  # direct match: QID15
  if (col %in% all_qids) {
    return(list(qid = col, iteration = 0L))
  }

  # loop iteration prefix: "1_QID15", "2_QID15_1"
  m <- regmatches(col, regexec("^([0-9]+)_(QID[0-9]+)", col))[[1]]
  if (length(m) == 3L && m[3] %in% all_qids) {
    return(list(qid = m[3], iteration = as.integer(m[2])))
  }

  # suffix: QID15_1, QID15_1_TEXT, QID15_2_3
  m <- regmatches(col, regexec("^(QID[0-9]+)_", col))[[1]]
  if (length(m) == 2L && m[2] %in% all_qids) {
    # try to detect iteration from suffix pattern
    iter <- detect_iteration_suffix(col, m[2])
    return(list(qid = m[2], iteration = iter))
  }

  NULL
}


#' Try to parse a column name as ExportTag-based
#' @noRd
parse_tag_column <- function(col, tag_to_qid, all_qids) {
  # direct match to a tag
  if (col %in% names(tag_to_qid)) {
    qid <- tag_to_qid[[col]]
    if (qid %in% all_qids) return(list(qid = qid, iteration = 0L))
  }

  # loop iteration prefix: "1_Q15", "2_Q15"
  m <- regmatches(col, regexec("^([0-9]+)_(.+)$", col))[[1]]
  if (length(m) == 3L) {
    base <- m[3]
    # strip any choice suffix from base to find the tag
    base_clean <- sub("_[0-9]+(_TEXT)?$", "", base)
    if (base_clean %in% names(tag_to_qid)) {
      qid <- tag_to_qid[[base_clean]]
      if (qid %in% all_qids) {
        return(list(qid = qid, iteration = as.integer(m[2])))
      }
    }
    if (base %in% names(tag_to_qid)) {
      qid <- tag_to_qid[[base]]
      if (qid %in% all_qids) {
        return(list(qid = qid, iteration = as.integer(m[2])))
      }
    }
  }

  # suffix: Q15_1, travel_mode_1, Q15_1_TEXT
  # try progressively shorter prefixes against tag_to_qid
  parts <- strsplit(col, "_")[[1]]
  if (length(parts) >= 2L) {
    for (k in seq(length(parts) - 1L, 1L)) {
      prefix <- paste(parts[1:k], collapse = "_")
      if (prefix %in% names(tag_to_qid)) {
        qid <- tag_to_qid[[prefix]]
        if (qid %in% all_qids) {
          return(list(qid = qid, iteration = 0L))
        }
      }
    }
  }

  NULL
}


#' Detect loop iteration number from a column name suffix
#'
#' For a column like `QID15_2_1` where `QID15` is the question and the question
#' is in a loop block, the first number after the QID is the choice/row and the
#' second (if present) might be the iteration. Qualtrics is inconsistent here;
#' we default to 0 (non-loop) and let the caller handle grouping.
#' @noRd
detect_iteration_suffix <- function(col, qid) {
  # For now, treat all sub-columns of a QID as iteration 0 (same question).
  # Loop iteration detection is handled by the prefix pattern (1_QID15).
  0L
}


# ==============================================================================
# ID column and finished detection
# ==============================================================================

#' Find the respondent ID column
#' @noRd
resolve_id_col <- function(responses, id_col) {
  if (!is.null(id_col)) {
    if (!id_col %in% names(responses)) {
      cli::cli_abort("Column {.val {id_col}} not found in responses.")
    }
    return(id_col)
  }
  candidates <- c("ResponseId", "response_id", "responseid", "id", "ID")
  for (cand in candidates) {
    if (cand %in% names(responses)) return(cand)
  }
  # fallback: first column with all unique values
  for (nm in names(responses)) {
    vals <- responses[[nm]]
    if (is.character(vals) && length(unique(vals)) == length(vals)) return(nm)
  }
  NULL
}


#' Detect whether each respondent finished the survey
#' @noRd
detect_finished <- function(responses) {
  for (col in c("Finished", "finished", "FINISHED")) {
    if (col %in% names(responses)) {
      return(parse_finished(responses[[col]]))
    }
  }
  rep(NA, nrow(responses))
}

#' Normalise a completion-status vector to TRUE / FALSE / NA.
#' Accepts logical, 1/0 (numeric or text), TRUE/FALSE and yes/no text in any
#' case. Anything else -- including blanks and other numbers -- is NA
#' ("status unknown"), never FALSE ("did not finish").
#' @noRd
parse_finished <- function(v) {
  if (is.logical(v)) return(v)
  s <- tolower(trimws(as.character(v)))
  out <- rep(NA, length(s))
  out[s %in% c("1", "true", "t", "yes", "y")]  <- TRUE
  out[s %in% c("0", "false", "f", "no", "n")] <- FALSE
  out
}


# ==============================================================================
# Predicted burden from response-inferred routes
# ==============================================================================

#' Infer loop counts and visit flags from responses, then run respondent_burden
#' @noRd
predict_from_responses <- function(qsf, responses, col_map, blocks, scheme) {
  n_resp <- nrow(responses)
  engine <- burden_engine(qsf, scheme = scheme)

  # infer loop iteration counts per loop block
  loop_blocks <- blocks[blocks$in_loop, ]
  routes <- data.frame(row.names = seq_len(n_resp))

  for (i in seq_len(nrow(loop_blocks))) {
    bid   <- loop_blocks$block_id[i]
    lo_qid <- loop_blocks$loop_on_qid[i]
    lo_max <- loop_blocks$loop_max[i]
    blk_qids <- loop_blocks$question_ids[[i]]

    # find max answered iteration for any question in this loop block
    iter_counts <- integer(n_resp)
    for (col in names(col_map)) {
      m <- col_map[[col]]
      if (m$qid %in% blk_qids && m$iteration > 0L) {
        v <- responses[[col]]
        has_val <- !is.na(v) & nzchar(trimws(as.character(v)))
        iter_counts <- pmax(iter_counts, as.integer(has_val) * m$iteration)
      }
    }

    # if no iteration-prefixed columns found, count non-blank columns per QID
    if (all(iter_counts == 0L)) {
      for (qid in blk_qids) {
        cols_for_q <- names(col_map)[vapply(col_map, function(m) identical(m$qid, qid), logical(1))]
        for (col in cols_for_q) {
          v <- responses[[col]]
          has_val <- !is.na(v) & nzchar(trimws(as.character(v)))
          iter_counts <- pmax(iter_counts, as.integer(has_val))
        }
      }
    }

    if (!is.na(lo_qid)) {
      routes[[paste0("loop_", lo_qid)]] <- pmin(iter_counts, lo_max)
    } else {
      routes[[paste0("loop_", bid)]] <- pmin(iter_counts, lo_max)
    }
  }

  # infer visit flags for optional blocks
  full_i <- which(!engine$paths$terminates_early)
  if (length(full_i) > 0L) {
    all_block_sets <- engine$paths$block_ids[full_i]
    common <- Reduce(intersect, all_block_sets)
    optional <- setdiff(unique(unlist(all_block_sets)), common)

    for (bid in optional) {
      blk_qids <- blocks$question_ids[blocks$block_id == bid][[1]]
      cols_for_blk <- names(col_map)[vapply(col_map, function(m) m$qid %in% blk_qids, logical(1))]
      if (length(cols_for_blk) == 0L) next

      visited <- rep(FALSE, n_resp)
      for (col in cols_for_blk) {
        v <- responses[[col]]
        visited <- visited | (!is.na(v) & nzchar(trimws(as.character(v))))
      }
      routes[[paste0("visit_", bid)]] <- visited
    }
  }

  if (ncol(routes) == 0L) {
    return(list(points = rep(NA_real_, n_resp)))
  }

  pred <- tryCatch(
    respondent_burden(qsf, routes = routes, scheme = scheme, engine = engine),
    error = function(e) NULL
  )

  if (is.null(pred)) {
    return(list(points = rep(NA_real_, n_resp)))
  }

  list(points = pred$pred_pts)
}
