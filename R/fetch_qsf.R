#' Fetch a survey definition from the Qualtrics API
#'
#' Downloads a survey's definition through the Qualtrics REST API and returns it
#' in the same `qsf_raw` shape [read_qsf()] produces from a `.qsf` file, so the
#' rest of the pipeline (`burden_report()` etc.) works unchanged.
#'
#' Needs an API token. Set `QUALTRICS_API_KEY` (and optionally
#' `QUALTRICS_BASE_URL`, e.g. `"https://fra1.qualtrics.com"`) in your
#' environment, or pass them as arguments. The token needs the
#' "Manage Survey" / read-definition permission.
#'
#' @param survey Survey id (`SV_...`) or any Qualtrics URL containing one
#'   (survey-builder link, distribution link, ...).
#' @param api_key Qualtrics API token. Defaults to `Sys.getenv("QUALTRICS_API_KEY")`.
#' @param base_url API base, e.g. `"https://fra1.qualtrics.com"`. Defaults to
#'   `Sys.getenv("QUALTRICS_BASE_URL")`, else derived from `survey` if it is a URL.
#'
#' @return A `qsf_raw` object.
#'
#' @examples
#' \dontrun{
#' Sys.setenv(QUALTRICS_API_KEY = "...", QUALTRICS_BASE_URL = "https://fra1.qualtrics.com")
#' r <- burden_report(fetch_qsf("SV_0xIVRCCRgC1lt8a"))
#' }
#' @export
fetch_qsf <- function(survey,
                      api_key = Sys.getenv("QUALTRICS_API_KEY"),
                      base_url = Sys.getenv("QUALTRICS_BASE_URL")) {
  if (!requireNamespace("httr2", quietly = TRUE)) {
    cli::cli_abort("{.pkg httr2} is required for {.fn fetch_qsf}. Install it, or download the .qsf and use {.fn read_qsf}.")
  }
  id <- extract_survey_id(survey)
  if (is.na(id)) cli::cli_abort("Could not find a survey id ({.code SV_...}) in {.val {survey}}.")

  if (!nzchar(base_url) && grepl("://", survey)) {
    base_url <- sub("(^[a-z]+://[^/]+).*", "\\1", survey)
  }
  if (!nzchar(base_url)) {
    cli::cli_abort(c(
      "No Qualtrics API base URL.",
      i = "Set {.envvar QUALTRICS_BASE_URL} (e.g. {.val https://fra1.qualtrics.com}) or pass {.arg base_url}.",
      i = "It is the {.emph datacenter} host, which may differ from your survey-builder host."
    ))
  }
  base_url <- normalise_base_url(base_url)
  if (!nzchar(api_key)) {
    cli::cli_abort("No API token. Set {.envvar QUALTRICS_API_KEY} or pass {.arg api_key}.")
  }

  resp <- httr2::request(base_url) |>
    httr2::req_url_path_append("API", "v3", "survey-definitions", id) |>
    httr2::req_headers("X-API-TOKEN" = api_key) |>
    httr2::req_user_agent("surveyBurden (R package)") |>
    httr2::req_error(body = qualtrics_error_body) |>
    httr2::req_perform()

  body <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  as_qsf_raw(body$result %||% body)
}

#' Add a scheme if missing and drop any path/trailing slash.
#' @noRd
normalise_base_url <- function(x) {
  x <- trimws(x)
  if (!grepl("://", x)) x <- paste0("https://", x)
  sub("(^[a-z]+://[^/]+).*", "\\1", x)
}

#' Pull an `SV_...` id out of a string (id or URL).
#' @noRd
extract_survey_id <- function(x) {
  m <- regmatches(x, regexpr("SV_[A-Za-z0-9]+", x))
  if (length(m) == 1L) m else NA_character_
}

#' @noRd
qualtrics_error_body <- function(resp) {
  j <- tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)
  msg <- j$meta$error$errorMessage %||% j$meta$httpStatus %||% "unknown error"
  paste0("Qualtrics API: ", msg)
}

#' Normalise a survey definition into the `qsf_raw` shape
#'
#' Accepts either the `.qsf` file shape (`SurveyEntry` + `SurveyElements` array)
#' or the Qualtrics API `survey-definitions` shape (`Questions`/`Blocks`/
#' `SurveyFlow` objects) and returns the former.
#'
#' @param def A parsed survey definition list.
#' @return A `qsf_raw` object.
#' @export
as_qsf_raw <- function(def) {
  if (!is.null(def$SurveyElements) && !is.null(def$SurveyEntry)) {
    return(structure(def, class = "qsf_raw"))
  }

  entry_keys <- setdiff(names(def), c("Questions", "Blocks", "SurveyFlow",
                                      "SurveyElements", "ResponseSets",
                                      "Scoring", "ProjectInfo", "Loop"))
  entry <- def[entry_keys]

  elements <- list()

  if (!is.null(def$Blocks)) {
    elements[[length(elements) + 1]] <- list(
      Element = "BL", PrimaryAttribute = "Survey Blocks",
      SecondaryAttribute = NULL, Payload = def$Blocks
    )
  }
  if (!is.null(def$SurveyFlow)) {
    elements[[length(elements) + 1]] <- list(
      Element = "FL", PrimaryAttribute = "Survey Flow",
      SecondaryAttribute = NULL, Payload = def$SurveyFlow
    )
  }
  for (qid in names(def$Questions %||% list())) {
    payload <- def$Questions[[qid]]
    payload$QuestionID <- payload$QuestionID %||% qid
    elements[[length(elements) + 1]] <- list(
      Element = "SQ", PrimaryAttribute = qid,
      SecondaryAttribute = payload$QuestionText %||% NULL, Payload = payload
    )
  }

  structure(list(SurveyEntry = entry, SurveyElements = elements),
            class = "qsf_raw")
}
