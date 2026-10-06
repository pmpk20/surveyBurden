# Reading and mapping response data, shared by respondent_burden() and
# validate_times().

# ==============================================================================
# Qualtrics export header rows
# ==============================================================================

#' Read response data given as a CSV path; a data frame passes through.
#' Columns are read as text with their names unchanged, so a raw Qualtrics
#' export keeps its header rows for [drop_qualtrics_header_rows()].
#' @noRd
read_responses <- function(x, arg = "responses") {
  if (is.data.frame(x)) return(x)
  if (is.character(x) && length(x) == 1L) {
    if (!file.exists(x)) cli::cli_abort("{.arg {arg}} file not found: {.file {x}}.")
    return(utils::read.csv(x, check.names = FALSE, stringsAsFactors = FALSE,
                           colClasses = "character", encoding = "UTF-8"))
  }
  cli::cli_abort("{.arg {arg}} must be a data frame or the path to a CSV file.")
}

#' Drop the label and ImportId rows a raw Qualtrics CSV export carries.
#'
#' Removes only leading rows that are recognisably Qualtrics metadata: a cell
#' holding ImportId JSON (`{"ImportId":...}`), or a system column holding its
#' own label (`ResponseId` = "Response ID", `Finished` = "Finished",
#' `StartDate` = "Start Date"). Stops at the first row that is neither, so
#' respondent data -- including a cleaned export whose first rows are real
#' respondents -- is never dropped on guesswork.
#' @return list(data, n_dropped); `data` keeps the input's attributes
#'   (e.g. `col_map`).
#' @noRd
drop_qualtrics_header_rows <- function(responses, quiet = FALSE) {
  labels <- c(ResponseId = "Response ID", Finished = "Finished",
              StartDate = "Start Date", EndDate = "End Date",
              RecordedDate = "Recorded Date")
  labels <- labels[names(labels) %in% names(responses)]
  is_header <- function(i) {
    row <- vapply(responses[i, , drop = FALSE],
                  function(v) trimws(as.character(v)), character(1))
    any(grepl('^\\{"ImportId":', row)) ||
      any(!is.na(row[names(labels)]) & row[names(labels)] == labels)
  }

  n <- 0L
  while (n < nrow(responses) && n < 3L && is_header(n + 1L)) n <- n + 1L
  if (n == 0L) return(list(data = responses, n_dropped = 0L))

  keep <- setdiff(names(attributes(responses)), c("names", "row.names", "class"))
  out  <- responses[-seq_len(n), , drop = FALSE]
  for (a in keep) attr(out, a) <- attr(responses, a)
  # keep the ImportId row: it names each column's QID whatever the column is
  # called (custom export tags, choice export tags), see build_col_map()
  for (i in seq_len(n)) {
    row <- vapply(responses[i, , drop = FALSE],
                  function(v) trimws(as.character(v)), character(1))
    is_imp <- grepl('^\\{"ImportId":"', row)
    if (any(is_imp)) {
      ids <- rep(NA_character_, length(row))
      ids[is_imp] <- sub('^\\{"ImportId":"([^"]*)".*$', "\\1", row[is_imp])
      attr(out, "import_ids") <- stats::setNames(ids, names(responses))
      break
    }
  }
  if (!quiet) {
    cli::cli_inform(
      "Removed {n} Qualtrics header row{?s} (question labels / ImportId) from the top of {.arg responses}."
    )
  }
  list(data = out, n_dropped = n)
}


# ==============================================================================
# Column-to-QID mapping
# ==============================================================================

#' Map response data columns to question ids
#'
#' Tries these strategies in order:
#' 1. A `col_map` attribute on the data frame (see [user_col_mapping()])
#' 2. The ImportId row of a raw Qualtrics CSV export (kept by
#'    [drop_qualtrics_header_rows()] as the `import_ids` attribute). When a
#'    column has an ImportId it decides alone: `QID15_1` and `2_QID15` map,
#'    anything else (embedded data, metadata) does not.
#' 3. Direct QID-based column names (`QID15`, `QID15_1`)
#' 4. ExportTag-based names from the QSF (`Q15`, `travel_mode_1`)
#'
#' Columns Qualtrics fills automatically -- display order (`_DO`), page-timing
#' clicks and browser meta data -- are never mapped: they are not answers.
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
  import_ids <- attr(responses, "import_ids")

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

    # strategy 1: user-supplied attribute (overrides automatic matching)
    if (!is.null(user_map) && col %in% names(user_map)) {
      mapping <- user_col_mapping(col, user_map[[col]], all_qids)
    }

    # strategy 2: the export's ImportId row, authoritative where present
    imp <- if (is.null(mapping) && !is.null(import_ids) && col %in% names(import_ids))
      import_ids[[col]] else NA_character_
    if (!is.na(imp)) {
      mapping <- parse_import_id(imp, all_qids)
      if (!is.null(mapping)) {
        result[[col]] <- mapping
        mapped <- mapped + 1L
      } else if (is_question_import_id(imp)) {
        # a question column whose QID is not a live question of this survey;
        # embedded data, metadata and automatic columns are expected, not counted
        unmapped <- unmapped + 1L
      }
      next
    }
    if (is.null(mapping) && is_auto_column_name(col)) next

    # strategy 3: QID-based column name
    if (is.null(mapping)) {
      mapping <- parse_qid_column(col, all_qids)
    }

    # strategy 4: ExportTag-based column name (exact then case-insensitive)
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
      i = "Pass the raw Qualtrics CSV export (its ImportId row maps the columns), or use {.code qualtRics::fetch_survey(survey_id, label = FALSE, convert = FALSE, import_id = TRUE)}."
    ))
  }

  attr(result, "n_unmapped") <- unmapped
  result
}


#' Resolve one user-supplied `col_map` entry to `list(qid, iteration)`.
#' The entry is either a QID string -- the loop iteration then comes from an
#' `N_` column-name prefix (`2_mycol`), as in automatic matching, else 0 -- or
#' `list(qid = , iteration = )` giving the iteration explicitly. Returns NULL
#' for a QID not in the survey.
#' @noRd
user_col_mapping <- function(col, entry, all_qids) {
  if (is.list(entry)) {
    qid  <- as.character(entry$qid %||% NA_character_)[1]
    iter <- entry$iteration
  } else {
    qid  <- as.character(entry)[1]
    iter <- NULL
  }
  if (is.na(qid) || !qid %in% all_qids) return(NULL)
  if (is.null(iter)) {
    m <- regmatches(col, regexec("^([0-9]+)_", col))[[1]]
    iter <- if (length(m) == 2L) m[2] else 0L
  }
  list(qid = qid, iteration = as.integer(iter))
}


#' Suffixes of columns Qualtrics fills automatically (not answers): display
#' order, page-timing clicks and browser meta data.
#' @noRd
auto_suffix_re <- "^_(DO(_.*)?|FIRST_CLICK|LAST_CLICK|PAGE_SUBMIT|CLICK_COUNT|BROWSER|VERSION|OS|RESOLUTION)$"

#' Map one ImportId (`QID15`, `QID15_1_TEXT`, `2_QID15_3`) to
#' `list(qid, iteration)`; NULL for a non-question id, an automatic column
#' (see `auto_suffix_re`) or a QID not in the survey.
#' @noRd
parse_import_id <- function(id, all_qids) {
  m <- regmatches(id, regexec("^(([0-9]+)_)?(QID[0-9]+)(.*)$", id))[[1]]
  if (length(m) != 5L || !m[4] %in% all_qids) return(NULL)
  if (grepl(auto_suffix_re, m[5])) return(NULL)
  list(qid = m[4], iteration = if (nzchar(m[3])) as.integer(m[3]) else 0L)
}

#' Does an ImportId name a question's answer column (not an automatic one)?
#' @noRd
is_question_import_id <- function(id) {
  m <- regmatches(id, regexec("^(([0-9]+)_)?(QID[0-9]+)(.*)$", id))[[1]]
  length(m) == 5L && !grepl(auto_suffix_re, m[5])
}

#' An automatic column by name, for exports without an ImportId row: display
#' order (`Q5_DO`, `Q5_DO_2`), or a QID-named automatic column
#' (`QID5_FIRST_CLICK`, as `fetch_survey(import_id = TRUE)` names it).
#' @noRd
is_auto_column_name <- function(col) {
  grepl("_DO(_[0-9]+)?$", col) ||
    (grepl("^([0-9]+_)?QID[0-9]+", col) && !is_question_import_id(col))
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
