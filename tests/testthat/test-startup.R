test_that("the startup message shows the version, title and citation", {
  msg <- startup_message()
  expect_match(msg, paste0("Burden ", utils::packageVersion("surveyBurden")), fixed = TRUE)
  expect_match(msg, utils::packageDescription("surveyBurden")$Title, fixed = TRUE)
  expect_match(msg, "Please cite:", fixed = TRUE)
  expect_message(.onAttach("", "surveyBurden"), class = "packageStartupMessage")
})
