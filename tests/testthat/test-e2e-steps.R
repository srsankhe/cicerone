# WP4 end-to-end coverage: `$set_steps()`/`$clear_steps()`/`$set_config()`
# and `show_if`, driven through a real browser via shinytest2/chromote.
# Skipped unless CICERONE_E2E=true (see helper-e2e.R for the install
# requirement this implies). Fixture: `guide_steps` (id "e2e_steps") in
# tests/testthat/apps/e2e/app.R -- 3 steps, step 2's `show_if` reads the
# `#show_step2` checkbox.

test_that("clear_steps()$step()$set_steps() rebuilds the tour to one step", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_rebuild_steps")
  app$wait_for_idle()

  app$click(input = "btn_start_steps")
  app$wait_for_value(input = "e2e_steps_cicerone_state")

  state <- input_value(app, "e2e_steps_cicerone_state")
  expect_equal(state$total_steps, 1)
  expect_equal(state$index, 0)
})

test_that("an unchecked show_if predicate filters its step out of the tour", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_steps")
  app$wait_for_value(input = "e2e_steps_cicerone_state")
  state0 <- input_value(app, "e2e_steps_cicerone_state")
  expect_equal(state0$total_steps, 2)
  expect_equal(state0$highlighted, "el1")

  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_steps_cicerone_state", ignore = list(state0))

  state1 <- input_value(app, "e2e_steps_cicerone_state")
  expect_equal(state1$index, 1)
  expect_equal(state1$highlighted, "el3")
})

test_that("a checked show_if predicate keeps its step in the tour", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$set_inputs(show_step2 = TRUE)
  app$click(input = "btn_start_steps")
  app$wait_for_value(input = "e2e_steps_cicerone_state")

  state <- input_value(app, "e2e_steps_cicerone_state")
  expect_equal(state$total_steps, 3)
  expect_equal(state$highlighted, "el1")
})

test_that("show_if is re-evaluated fresh on every start", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_steps")
  app$wait_for_value(input = "e2e_steps_cicerone_state")
  expect_equal(input_value(app, "e2e_steps_cicerone_state")$total_steps, 2)

  app$click(input = "btn_reset_steps")
  app$wait_for_value(input = "e2e_steps_cicerone_ended")

  app$set_inputs(show_step2 = TRUE)
  app$click(input = "btn_start_steps")
  app$wait_for_value(input = "e2e_steps_cicerone_started")
  app$wait_for_idle()

  expect_equal(input_value(app, "e2e_steps_cicerone_state")$total_steps, 3)
})

test_that("requesting a hidden step with nothing visible after it falls back to the last visible step", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  # guide_showif_tail: el1, el2 visible; el3 (the requested, last, index
  # 2) is always hidden -- Copilot review item C: this must fall back to
  # the LAST VISIBLE step (el2, index 1), not fire no_visible_steps
  # (which only fires when the filtered list is empty).
  app$click(input = "btn_start_showif_tail")
  app$wait_for_value(input = "e2e_showif_tail_cicerone_state")

  state <- input_value(app, "e2e_showif_tail_cicerone_state")
  expect_equal(state$total_steps, 2)
  expect_equal(state$index, 1)
  expect_equal(state$highlighted, "el2")

  # the tour actually drove (proven by the _state wait above succeeding
  # at all): no_visible_steps only fires -- without ever driving -- when
  # the filtered list is empty, which it is not here (2 of 3 steps show)
  started <- input_value(app, "e2e_showif_tail_cicerone_started")
  expect_equal(started$index, 1)
})

test_that("set_config(overlay_opacity = ) mid-tour updates the live overlay and the tour keeps working", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_steps")
  app$wait_for_value(input = "e2e_steps_cicerone_state")
  state0 <- input_value(app, "e2e_steps_cicerone_state")

  app$click(input = "btn_set_overlay_opacity")
  app$wait_for_idle()

  # driver.js only ever sets `.driver-overlay path`'s `style.opacity` at
  # creation; a mid-tour `overlay_opacity` change is otherwise never
  # reflected until the tour ends and a new one starts -- cicerone's
  # `cicerone-set-config` handler patches the current overlay directly
  # (see srcjs/exts/tour.js) so it takes effect immediately.
  opacity <- app$get_js(
    "document.querySelector('.driver-overlay path').style.opacity"
  )
  expect_equal(as.numeric(opacity), 0.1)

  # the tour must still be fully functional after set_config(): Next
  # moves it, proving `cicerone-set-config` did not lose `steps` or reset
  # driver.js's live position (see the design note in tour.js on why
  # `setSteps()` is not called separately here).
  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_steps_cicerone_state", ignore = list(state0))

  state1 <- input_value(app, "e2e_steps_cicerone_state")
  expect_equal(state1$index, 1)
})
