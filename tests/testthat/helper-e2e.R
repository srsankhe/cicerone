# End-to-end test helpers (shinytest2 + chromote).
#
# shinytest2 launches the fixture app (tests/testthat/apps/e2e/app.R) in a
# separate, freshly-started R process. That process does `library(cicerone)`
# against whatever is on the library search path for that process -- it does
# NOT pick up the in-development sources of this package the way
# `testthat::test_local()` does for the rest of the suite. Before running
# these tests (locally or in CI), install the current worktree so the
# fixture app's `library(cicerone)` sees the code under test:
#
#   Rscript -e 'install.packages(".", repos = NULL, type = "source")'
#
# Tests are skipped unless CICERONE_E2E=true, so this requirement never
# affects `R CMD check`, CRAN, or a plain `testthat::test_local()` run.

skip_e2e <- function() {
  testthat::skip_if_not(
    Sys.getenv("CICERONE_E2E") == "true",
    "set CICERONE_E2E=true to run end-to-end (shinytest2) tests"
  )
  testthat::skip_if_not_installed("shinytest2")
}

e2e_app <- function() {
  shinytest2::AppDriver$new(
    testthat::test_path("apps/e2e"),
    load_timeout = 20000,
    variant = NULL
  )
}

# Read a Shiny input's live value from the running app (client-side, via
# shinytest2's JS bridge) without needing a verbatimTextOutput for it.
input_value <- function(app, name) {
  app$get_value(input = name)
}
