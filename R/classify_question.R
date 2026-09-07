#' Classify a single Qualtrics question payload
#'
#' Maps a Qualtrics `QuestionType` / `Selector` / `SubSelector` combination to a
#' standardised question type and extracts the structural fields the burden
#' scorer needs. This function reads structure only, never semantics: a two-option
#' multiple choice is `single_choice` whether it means yes/no or something else.
#'
#' @param payload The `Payload` list of one `SQ` survey element.
#'
#' @return A one-row [tibble][tibble::tibble] with columns `question_id`,
#'   `std_type`, `qualtrics_type`, `selector`, `subselector`, `n_options`,
#'   `n_rows`, `n_cols`, `text_words`, `max_label_words` (longest response
#'   option / matrix label, in words; `NA` if the question has no labels),
#'   `label_text` (all response/answer labels lowercased and joined with
#'   `" | "`, truncated; `NA` if none), `options_numeric` (`TRUE` if the
#'   question has >= 3 response options and every one is a number),
#'   `question_text` (HTML-stripped, truncated to 200 characters), `is_hidden`
#'   (`TRUE` if injected CSS/JS hides the question from the respondent),
#'   `has_display_logic`, `display_logic_refs` (list column), `has_validation`
#'   and `flag`.
#'
#' @details `flag` is one of `"auto"` (confident structural mapping),
#'   `"inferred"` (mapping needs an assumption, e.g. dropdown scored by option
#'   count, short text that might be a code field), `"manual"` (reserved for cases
#'   a human must check) or `"unknown"` (unmapped type).
#'
#' @export
classify_question <- function(payload) {
  qt  <- payload$QuestionType %||% NA_character_
  sel <- payload$Selector %||% NA_character_
  sub <- payload$SubSelector %||% NA_character_

  spec <- classify_type(qt, sel, sub)

  n_options <- length(payload$Choices %||% list())
  n_rows    <- if (identical(spec$std_type, "matrix")) length(payload$Choices %||% list()) else NA_integer_
  n_cols    <- if (identical(spec$std_type, "matrix")) length(payload$Answers %||% list()) else NA_integer_
  if (identical(spec$std_type, "matrix")) n_options <- NA_integer_

  refs <- display_logic_refs(payload$DisplayLogic)

  labels <- c(label_texts(payload$Choices), label_texts(payload$Answers))
  labels <- labels[nzchar(labels)]
  max_label_words <- if (length(labels)) {
    max(vapply(labels, count_words, integer(1)))
  } else {
    NA_integer_
  }
  label_text <- if (length(labels)) {
    joined <- tolower(paste(labels, collapse = " | "))
    if (nchar(joined) > 200L) paste0(substr(joined, 1, 200L), "...") else joined
  } else {
    NA_character_
  }

  opt_labels <- label_texts(payload$Choices)
  opt_labels <- opt_labels[nzchar(opt_labels)]
  options_numeric <- length(opt_labels) >= 3 &&
    all(!is.na(suppressWarnings(as.numeric(gsub("[[:space:],]", "", opt_labels)))))

  tibble::tibble(
    question_id        = payload$QuestionID %||% NA_character_,
    std_type           = spec$std_type,
    qualtrics_type     = qt,
    selector           = sel,
    subselector        = sub,
    n_options          = as.integer(n_options),
    n_rows             = as.integer(n_rows),
    n_cols             = as.integer(n_cols),
    text_words         = count_words(payload$QuestionText %||% ""),
    max_label_words    = as.integer(max_label_words),
    label_text         = label_text,
    options_numeric    = options_numeric,
    question_text      = clean_question_text(payload$QuestionText %||% ""),
    is_hidden          = is_hidden_question(payload),
    has_display_logic  = !is.null(payload$DisplayLogic),
    display_logic_refs = list(refs),
    has_validation     = has_forced_response(payload$Validation),
    flag               = spec$flag
  )
}

#' TRUE if a question is hidden from the respondent via injected CSS/JS
#'
#' Rendering is not in the QSF, so this is a heuristic: it looks for CSS or JS
#' that targets one of Qualtrics's fixed DOM selectors to hide the question
#' container or the navigation buttons. Those selector names have been stable
#' across Qualtrics themes and versions for years.
#' @noRd
is_hidden_question <- function(payload) {
  blob <- paste(payload$QuestionText %||% "", payload$QuestionJS %||% "")
  if (!nzchar(trimws(blob))) return(FALSE)
  sel <- "\\.QuestionOuter|\\.QuestionBody|#Buttons|#NextButton|#PreviousButton|\\.Skin"
  hide <- "display\\s*:\\s*none|visibility\\s*:\\s*hidden|\\.hide\\s*\\(|\\.css\\(\\s*['\"]display['\"]\\s*,\\s*['\"]none"
  grepl(sel, blob, perl = TRUE) && grepl(hide, blob, perl = TRUE)
}

#' Core type lookup: (QuestionType, Selector, SubSelector) -> std_type + flag
#' @noRd
classify_type <- function(qt, sel, sub) {
  sc  <- function(std, flag) list(std_type = std, flag = flag)

  if (identical(qt, "MC")) {
    if (sel %in% c("MAVR", "MACOL", "MAHR", "MSB")) return(sc("multi_choice", "auto"))
    if (identical(sel, "DL"))                       return(sc("single_choice", "inferred"))
    if (sel %in% c("SAVR", "SAHR", "SACOL", "DL", "SB", "NPS")) return(sc("single_choice", "auto"))
    return(sc("single_choice", "inferred"))
  }
  if (identical(qt, "Matrix")) {
    if (identical(sub, "MultipleAnswer")) return(sc("matrix", "inferred"))
    return(sc("matrix", "auto"))
  }
  if (identical(qt, "TE")) {
    if (sel %in% c("ML", "ESTB", "FORM")) return(sc("open_text", "auto"))
    return(sc("open_text", "inferred"))
  }
  if (identical(qt, "Slider"))  return(sc("slider", "inferred"))
  if (identical(qt, "RO"))      return(sc("ranking", "auto"))
  if (identical(qt, "CS"))      return(sc("constant_sum", "auto"))
  if (identical(qt, "DB"))      return(sc("descriptive", "inferred"))
  if (identical(qt, "Timing"))  return(sc("timing", "auto"))
  if (identical(qt, "Meta"))    return(sc("meta", "auto"))
  if (identical(qt, "Captcha")) return(sc("captcha", "auto"))

  sc("unknown", "unknown")
}

#' Count words in a question stem, HTML stripped
#' @noRd
count_words <- function(html) {
  txt <- strip_html(html)
  if (!nzchar(txt)) return(0L)
  length(strsplit(txt, " ", fixed = TRUE)[[1]])
}

#' Plain-text label strings from a Choices / Answers list
#' @noRd
label_texts <- function(x) {
  if (is.null(x) || !length(x)) return(character(0))
  vapply(x, function(el) {
    if (is.character(el)) return(paste(el, collapse = " "))
    if (!is.list(el)) return("")
    el$Display %||% el$ChoiceText %||% el$Text %||% ""
  }, character(1))
}

#' HTML-stripped, whitespace-collapsed plain text of a question stem
#' @noRd
strip_html <- function(html) {
  txt <- gsub("<[^>]+>", " ", html %||% "")
  trimws(gsub("\\s+", " ", txt))
}

#' A readable, truncated question stem for display in reports.
#' @noRd
clean_question_text <- function(html, max_chars = 200L) {
  txt <- strip_html(html)
  if (nchar(txt) <= max_chars) return(txt)
  paste0(substr(txt, 1, max_chars), "...")
}

#' Prior question ids a DisplayLogic tree references
#' @noRd
display_logic_refs <- function(dl) {
  if (is.null(dl)) return(character(0))
  refs <- character(0)
  rec <- function(x) {
    if (is.list(x)) {
      if (!is.null(x$QuestionID)) refs <<- c(refs, x$QuestionID)
      lapply(x, rec)
    }
  }
  rec(dl)
  unique(refs)
}

#' TRUE if a question's Validation forces a response
#' @noRd
has_forced_response <- function(validation) {
  fr <- validation$Settings$ForceResponse %||% NULL
  !is.null(fr) && !identical(fr, "OFF")
}
