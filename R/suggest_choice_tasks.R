#' Suggest questions that may be stated-choice tasks
#'
#' A QSF does not mark a question as a stated-choice (choice-experiment) task,
#' and the attributes are often laid out in an HTML table or an image. This
#' function looks for likely candidates so you can check them and declare them
#' through the `choice_tasks` argument of [burden_report()] and the other
#' burden functions. It never scores anything itself.
#'
#' A visible single-choice question is suggested when any of these holds:
#' \itemize{
#'   \item its stem contains an HTML `<table>`;
#'   \item the nearest text item before it in the same block contains a
#'     `<table>` (the scenario shown above the choice);
#'   \item its stem contains an image (`<img>`) and at least one other such
#'     question is in the same block (choice tasks repeat; a lone image
#'     question is left out).
#' }
#' `n_alternatives` is the option count (an opt-out such as "neither" counts
#' as an alternative), or `NA` above five options, where the answer scale is
#' more likely a graded preference between fewer alternatives. `n_attributes`
#' is a guess: the table rows holding data cells (`<td>`), so a header row of
#' `<th>` cells only is not counted; `NA` when the attributes are in an image.
#' Check both counts against the questionnaire and fill in any `NA` before
#' passing the result to `choice_tasks` (which rejects `NA`).
#'
#' @param qsf A `qsf_raw` object or a path to a `.qsf` file.
#'
#' @return A [tibble][tibble::tibble], one row per suggested question, in
#'   survey order: `question_id`, `block_id`, `block_name`, `n_alternatives`,
#'   `n_attributes`, `n_in_block` (how many suggested questions share the
#'   block) and `evidence`.
#'
#' @examples
#' qsf_path <- system.file("extdata", "demo_travel_survey.qsf",
#'                          package = "surveyBurden")
#' suggest_choice_tasks(qsf_path)
#'
#' @export
suggest_choice_tasks <- function(qsf) {
  if (!inherits(qsf, "qsf_raw")) qsf <- read_qsf(qsf)
  catalogue <- parse_qsf(qsf)
  payloads  <- index_questions(qsf)

  html <- vapply(catalogue$question_id, function(q)
    as.character(payloads[[q]]$QuestionText %||% ""), character(1))
  has_table <- grepl("<table", html, ignore.case = TRUE)
  has_img   <- grepl("<img", html, ignore.case = TRUE)
  choice <- catalogue$std_type %in% "single_choice" &
    !(catalogue$is_hidden %in% TRUE) &
    !is.na(catalogue$n_options) & catalogue$n_options >= 2L

  # the nearest text item before each question in its block, if it has a table
  n <- nrow(catalogue)
  prev_table <- rep(NA_integer_, n)
  last_db <- NA_integer_
  for (k in seq_len(n)) {
    if (k > 1L && catalogue$block_id[k] != catalogue$block_id[k - 1L]) last_db <- NA_integer_
    if (choice[k] && !is.na(last_db) && has_table[last_db]) prev_table[k] <- last_db
    if (catalogue$std_type[k] %in% "descriptive") last_db <- k
  }

  img_only <- choice & has_img & !has_table & is.na(prev_table)
  img_n <- stats::ave(as.integer(img_only), catalogue$block_id, FUN = sum)
  keep <- choice & (has_table | !is.na(prev_table) | (img_only & img_n >= 2L))

  src <- ifelse(has_table, seq_len(n), prev_table)
  n_attr <- vapply(seq_len(n), function(k)
    if (is.na(src[k])) NA_integer_ else count_data_rows(html[src[k]]), integer(1))
  no <- catalogue$n_options
  evidence <- ifelse(has_table, "HTML table in the stem",
              ifelse(!is.na(prev_table),
                     paste0("HTML table in the text item before it (",
                            catalogue$question_id[ifelse(is.na(prev_table), 1L, prev_table)], ")"),
                     "image in the stem, repeated in the block (attributes not readable)"))
  evidence <- paste0(evidence, "; ", no, " options",
                     ifelse(!is.na(no) & no > 5,
                            " (more than 5: possibly a graded preference scale; set n_alternatives)",
                            ""))

  k <- which(keep)
  tibble::tibble(
    question_id    = catalogue$question_id[k],
    block_id       = catalogue$block_id[k],
    block_name     = catalogue$block_name[k],
    n_alternatives = ifelse(no[k] > 5, NA_integer_, as.integer(no[k])),
    n_attributes   = unname(n_attr[k]),
    n_in_block     = as.integer(table(catalogue$block_id[k])[catalogue$block_id[k]]),
    evidence       = unname(evidence[k])
  )
}

#' Table rows holding at least one `<td>` cell; `NA` when there are none.
#' @noRd
count_data_rows <- function(html) {
  rows <- regmatches(html, gregexpr("(?s)<tr\\b.*?</tr>", html, ignore.case = TRUE,
                                    perl = TRUE))[[1]]
  n <- sum(grepl("<td\\b", rows, ignore.case = TRUE, perl = TRUE))
  if (n == 0L) NA_integer_ else as.integer(n)
}
