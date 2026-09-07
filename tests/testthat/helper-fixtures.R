# Absolute path to the bundled demo survey. Under pkgload::load_all() and
# under R CMD check this resolves to inst/extdata/.
demo_qsf <- function() {
  system.file("extdata", "demo_travel_survey.qsf",
              package = "surveyBurden", mustWork = TRUE)
}
