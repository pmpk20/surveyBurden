#' Read a Qualtrics survey definition
#'
#' Loads a survey definition without simplifying its JSON structure, so nested
#' survey elements, flow nodes and logic objects are preserved as R lists.
#'
#' @param source One of:
#'   \itemize{
#'     \item a path to a `.qsf` file;
#'     \item a Qualtrics URL containing a survey id (`SV_...`) -- fetched via
#'       [fetch_qsf()] (needs `QUALTRICS_API_KEY` / `QUALTRICS_BASE_URL`);
#'     \item a bare survey id `SV_...` -- also fetched via [fetch_qsf()].
#'   }
#'
#' @return A list of class `qsf_raw` with components `SurveyEntry` and
#'   `SurveyElements`.
#'
#' @export
read_qsf <- function(source) {
  if (length(source) == 1L && file.exists(source)) {
    parsed <- jsonlite::fromJSON(source, simplifyVector = FALSE)
    if (!all(c("SurveyEntry", "SurveyElements") %in% names(parsed))) {
      cli::cli_abort(
        "{.path {source}} is not a valid QSF: missing {.field SurveyEntry} or \\
         {.field SurveyElements}."
      )
    }
    return(structure(parsed, class = "qsf_raw"))
  }

  if (length(source) == 1L && grepl("SV_[A-Za-z0-9]+", source)) {
    return(fetch_qsf(source))
  }

  cli::cli_abort(c(
    "{.arg source} is not a readable {.file .qsf} path or a Qualtrics survey id/URL.",
    i = "Got {.val {source}}."
  ))
}
