#' GfS / Axhausen burden weights
#'
#' The default scoring backend. Values are transcribed from Table 1 of
#' Heimgartner & Axhausen (2024), "Predicting Response Rates Once Again"
#' (*Findings*), which prints the GfS / ETH Zurich scheme (GfS Zurich 2006,
#' updated). Override any element and pass the result to [score_burden()].
#'
#' @return A named list of weights.
#'
#' @details Table 1 items and the names used here:
#' \tabular{lll}{
#'   GfS item \tab points \tab weight name \cr
#'   Question or transition (up to 3 lines) \tab 2.0 \tab `descriptive_base` \cr
#'   Each additional line \tab 1.0 \tab `descriptive_per_extra_line` \cr
#'   Closed yes/no answers \tab 1.0 \tab `yes_no` \cr
#'   Simple numerical answer (e.g. year of birth) \tab 1.0 \tab `numeric_answer` \cr
#'   Rating with up to 5 possibilities \tab 2.0 \tab `rating_small` \cr
#'   Rating with more than 5 possibilities \tab 3.0 \tab `rating_large` \cr
#'   Best of ranking with cards \tab 4.0 \tab `rank_base` \cr
#'   Second and each additional best ranking \tab 3.0 \tab `rank_per_item` \cr
#'   Answer to sub-questions of up to 5 words \tab 1.0 \tab `open_short` \cr
#'   Answer to sub-questions of up to 2 lines \tab 2.0 \tab `open_medium` \cr
#'   Half-open, < 8 possibilities (+ each additional) \tab 2.0 (+2.0) \tab `multi_small_base` / `multi_small_per_option` \cr
#'   Half-open, >= 8 possibilities (+ each additional) \tab 4.0 (+3.0) \tab `multi_large_base` / `multi_large_per_option` \cr
#'   Answer to "please specify" \tab 2.0 \tab `please_specify` \cr
#'   First answer to an open question \tab 6.0 \tab `open_essay` \cr
#'   Each additional answer to the open question \tab 3.0 \tab `open_essay_per_extra` \cr
#'   Filter \tab 0.5 \tab `filter` \cr
#'   Branching \tab 0.5 \tab `branching` \cr
#'   Stated choice question, 2 alternatives \tab 2.0 \tab `sc_2_alt` \cr
#'   Stated choice question, 3 alternatives \tab 3.0 \tab `sc_3_alt` \cr
#'   Per SC variable, per question \tab 1.0 \tab `sc_per_variable` \cr
#' }
#'
#' Not in Table 1 -- package-derived, used only where the QSF does not contain
#' the quantity the scheme needs:
#' \describe{
#'   \item{`slider`}{2.0 -- GfS has no slider; a graded slider is mapped to a
#'     rating, a magnitude slider to a numerical answer (see [score_burden()]).}
#'   \item{`matrix_cell_multi`}{0.5 -- a multiple-answer ("tick all that apply")
#'     grid has no Table 1 rule. Each of its `rows x cols` cells is treated as
#'     one trivial closed yes/no decision (GfS closed yes/no is 1.0), discounted
#'     for grid working-memory efficiency. This is orientation-invariant -- the
#'     score does not depend on which axis the QSF stored as rows. A documented
#'     inference, not GfS; the vignette describes the alternatives that were
#'     considered.}
#'   \item{`points_per_minute`}{12 -- the published GfS rule of thumb ("twelve
#'     points roughly correspond to a one-minute response time", Heimgartner &
#'     Axhausen 2024). Overridable: set `w$points_per_minute` on the returned
#'     list, or feed a survey-specific figure from [validate_times()].}
#'   \item{`words_per_line`}{12 -- a **pragmatic conversion heuristic**, not an
#'     empirically calibrated constant. GfS scores instruction text in rendered
#'     lines; a QSF has words, not a rendered width. Overridable, and exposed
#'     directly as `burden_report(words_per_line = ...)`. The single most
#'     sensitive assumption for `descriptive` items.}
#' }
#'
#' @export
gfs_weights <- function() {
  list(
    # --- Table 1 ---
    descriptive_base           = 2.0,
    descriptive_per_extra_line = 1.0,
    yes_no                     = 1.0,
    numeric_answer             = 1.0,
    rating_small               = 2.0,
    rating_large               = 3.0,
    rank_base                  = 4.0,
    rank_per_item              = 3.0,
    open_short                  = 1.0,
    open_medium                 = 2.0,
    multi_small_base           = 2.0,
    multi_small_per_option     = 2.0,
    multi_large_base           = 4.0,
    multi_large_per_option     = 3.0,
    multi_large_threshold      = 8L,
    please_specify             = 2.0,
    open_essay                  = 6.0,
    open_essay_per_extra        = 3.0,
    filter                     = 0.5,
    branching                  = 0.5,
    sc_2_alt                   = 2.0,
    sc_3_alt                   = 3.0,
    sc_per_variable            = 1.0,

    # --- our additions / proxies ---
    slider                     = 2.0,
    matrix_cell_multi          = 0.5,
    captcha                    = 0.5,

    # --- conversions / proxies ---
    points_per_minute          = 12,
    words_per_line             = 12
  )
}
