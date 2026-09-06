# Baseline end-to-end coverage for the WP0 srcjs split: every Shiny input
# the bridge sets, driven through a real browser via shinytest2/chromote.
# Skipped unless CICERONE_E2E=true (see helper-e2e.R for the install
# requirement this implies).

test_that("starting the tour highlights the first step", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")

  state <- input_value(app, "e2e_cicerone_state")
  expect_equal(state$index, 0)
})

test_that("clicking next fires _next and advances state to index 1", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")
  state0 <- input_value(app, "e2e_cicerone_state")
  expect_equal(state0$index, 0)

  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_cicerone_next")
  app$wait_for_value(input = "e2e_cicerone_state", ignore = list(state0))

  nxt <- input_value(app, "e2e_cicerone_next")
  expect_false(is.null(nxt))

  state1 <- input_value(app, "e2e_cicerone_state")
  expect_equal(state1$index, 1)
})

test_that("$move_to(2) moves the tour to step index 1 (1-based argument)", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")
  state0 <- input_value(app, "e2e_cicerone_state")

  # $move_to() takes a 1-based step, so move_to(2) targets the *second*
  # step, JS/0-based index 1 -- see `move_to()` in R/steps.R and the
  # existing "methods send the right messages" unit test.
  app$click(input = "btn_move_to_2")
  app$wait_for_value(input = "e2e_cicerone_state", ignore = list(state0))

  state <- input_value(app, "e2e_cicerone_state")
  expect_equal(state$index, 1)
  expect_equal(state$highlighted, "el2")
})

test_that("$reset() fires _reset as TRUE", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")

  app$click(input = "btn_reset")
  app$wait_for_value(input = "e2e_cicerone_reset")

  expect_true(isTRUE(input_value(app, "e2e_cicerone_reset")))
  expect_true(isTRUE(input_value(app, "cicerone_reset")))
})

test_that("a tab step activates the Shiny tab before highlighting", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")
  state0 <- input_value(app, "e2e_cicerone_state")
  expect_equal(state0$index, 0)

  # step 1 (index 0) -> step 2 (index 1) -> step 3 (index 2), which
  # targets #in_tab2 on the "Second" tab.
  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_cicerone_state", ignore = list(state0))
  state1 <- input_value(app, "e2e_cicerone_state")
  expect_equal(state1$index, 1)

  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_cicerone_state", ignore = list(state1))

  state2 <- input_value(app, "e2e_cicerone_state")
  expect_equal(state2$index, 2)
  expect_equal(state2$highlighted, "in_tab2")
  expect_equal(input_value(app, "tabs"), "Second")
})

test_that("showing hints and clicking the beacon fires _hint_opened", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_show_hints")
  app$wait_for_js("document.querySelector('.driver-hint') !== null")

  app$click(selector = ".driver-hint")
  app$wait_for_value(input = "e2e_hints_cicerone_hint_opened")

  opened <- input_value(app, "e2e_hints_cicerone_hint_opened")
  expect_equal(opened$element, "el3")
})
