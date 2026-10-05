.onAttach <- function(libname, pkgname) {
  packageStartupMessage(startup_message(pkgname))
}

#' Banner shown by `library(surveyBurden)`: a branching survey path, the
#' version, the package title and the citation. The version, title and
#' citation are read from DESCRIPTION and inst/CITATION, so they stay current.
#' @noRd
startup_message <- function(pkgname = "surveyBurden") {
  desc <- utils::packageDescription(pkgname)
  cite <- tryCatch(
    gsub("[_<>]", "", format(utils::citation(pkgname), style = "text")),
    error = function(e) NULL)
  paste(c(
    "",
    "                  .-- Q2 -- Q3 --.",
    paste0("  survey -- Q1 --+               +-- Burden ", desc$Version),
    "                  '-- Q4 --------'",
    "",
    desc$Title,
    "Docs: https://pmpk20.github.io/surveyBurden/",
    "",
    if (length(cite)) strwrap(paste("Please cite:", cite[1]), width = 72),
    "Use citation(\"surveyBurden\") for BibTeX."
  ), collapse = "\n")
}
