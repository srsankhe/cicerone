# WP1 end-to-end coverage: tour lifecycle inputs (`_started`, `_ended`,
# `_event`), reason detection, and driver.js-parity edge cases, driven
# through a real browser via shinytest2/chromote. Skipped unless
# CICERONE_E2E=true (see helper-e2e.R for the install requirement this
# implies).

test_that("starting the tour fires _started once, and move_to() does not re-fire it", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_started")

  started <- input_value(app, "e2e_cicerone_started")
  expect_equal(started$index, 0)
  expect_equal(started$total_steps, 3)

  app$click(input = "btn_move_to_2")
  app$wait_for_value(input = "e2e_cicerone_state")
  app$wait_for_idle()

  # move_to() re-highlights without a fresh drive(); `_started` must not
  # have re-fired (it would report index 1 if it had)
  started_after <- input_value(app, "e2e_cicerone_started")
  expect_equal(started_after$index, 0)
})

test_that("clicking Done on the last step ends the tour with reason done", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")
  state0 <- input_value(app, "e2e_cicerone_state")

  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_cicerone_state", ignore = list(state0))
  state1 <- input_value(app, "e2e_cicerone_state")

  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_cicerone_state", ignore = list(state1))
  state2 <- input_value(app, "e2e_cicerone_state")
  expect_equal(state2$index, 2)

  # last step: the same button now reads "Done"
  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_cicerone_ended")

  ended <- input_value(app, "e2e_cicerone_ended")
  expect_equal(ended$reason, "done")
  expect_true(ended$completed)
  expect_equal(ended$index, 2)
  expect_equal(ended$total_steps, 3)
  expect_false(is.null(input_value(app, "e2e_cicerone_next")))
})

test_that("clicking the close button ends the tour with reason close", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")

  app$click(selector = ".driver-popover-close-btn")
  app$wait_for_value(input = "e2e_cicerone_ended")

  ended <- input_value(app, "e2e_cicerone_ended")
  expect_equal(ended$reason, "close")
  expect_false(ended$completed)
})

test_that("$reset() ends the tour with reason programmatic", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")

  app$click(input = "btn_reset")
  app$wait_for_value(input = "e2e_cicerone_ended")

  ended <- input_value(app, "e2e_cicerone_ended")
  expect_equal(ended$reason, "programmatic")
  expect_false(ended$completed)
})

test_that("pressing Escape ends the tour with reason dismissed", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")

  # driver.js 1.8.0 detects Escape on `keyup` (see `Q()`/`ee()` in
  # driver.js.mjs, which binds `Q` to `keyup` and reserves `keydown` for
  # Tab-trapping only), not `keydown`
  app$run_js(
    "document.dispatchEvent(new KeyboardEvent('keyup', {key: 'Escape', bubbles: true}))"
  )
  app$wait_for_value(input = "e2e_cicerone_ended")

  ended <- input_value(app, "e2e_cicerone_ended")
  expect_equal(ended$reason, "dismissed")
})

test_that("clicking the overlay ends the tour with reason dismissed", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")

  # driver.js only treats a click on the overlay's `<path>` cutout as an
  # overlay click (see `k()` in driver.js.mjs), not the `<svg>` wrapper.
  # `app$click(selector=)` calls the DOM `.click()` method, which SVG
  # elements in this Chrome build don't implement, so dispatch a real
  # MouseEvent instead.
  app$run_js(
    "document.querySelector('.driver-overlay path').dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}))"
  )
  app$wait_for_value(input = "e2e_cicerone_ended")

  ended <- input_value(app, "e2e_cicerone_ended")
  expect_equal(ended$reason, "dismissed")
})

test_that("the _event stream for a full run is started, highlighted, next, highlighted, next, highlighted, done, ended", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")
  state0 <- input_value(app, "e2e_cicerone_state")

  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_cicerone_state", ignore = list(state0))
  state1 <- input_value(app, "e2e_cicerone_state")

  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_cicerone_state", ignore = list(state1))

  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_cicerone_ended")
  app$wait_for_idle()

  log <- app$get_value(export = "event_log")
  expect_equal(
    strsplit(log, ",")[[1]],
    c(
      "started", "highlighted", "next", "highlighted", "next",
      "highlighted", "done", "ended"
    )
  )
})

test_that("a step's on_close returning false keeps the tour open", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_close_false")
  app$wait_for_value(input = "e2e_close_false_cicerone_state")

  app$click(selector = ".driver-popover-close-btn")
  app$wait_for_idle()

  expect_true(app$get_js("document.querySelector('.driver-popover') !== null"))
  expect_null(input_value(app, "e2e_close_false_cicerone_ended"))
})

test_that("driver.js parity: an on_next-only last step still fires on Done, ending with reason done", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_parity")
  app$wait_for_value(input = "e2e_parity_cicerone_state")

  # the sole step is also the last step, so the button reads "Done"
  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_parity_cicerone_ended")

  expect_true(isTRUE(input_value(app, "last_next_fired")))
  expect_false(is.null(input_value(app, "e2e_parity_cicerone_next")))

  ended <- input_value(app, "e2e_parity_cicerone_ended")
  expect_equal(ended$reason, "done")
  expect_true(ended$completed)
})

test_that("a config-level on_close_click that destroys itself does not double-destroy", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_close_destroy")
  app$wait_for_value(input = "e2e_close_destroy_cicerone_state")

  app$click(selector = ".driver-popover-close-btn")
  app$wait_for_value(input = "e2e_close_destroy_cicerone_ended")
  app$wait_for_idle()

  ended <- input_value(app, "e2e_close_destroy_cicerone_ended")
  expect_equal(ended$reason, "close")
  expect_equal(app$get_value(export = "close_destroy_ended_count"), 1)

  logs <- app$get_logs()
  errors <- logs[logs$location == "chromote" & logs$level == "error", ]
  expect_equal(nrow(errors), 0)
})

test_that("a step-level on_highlighted override still fires _state/_started and event:highlighted", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_step_highlighted")
  app$wait_for_value(input = "e2e_step_highlighted_cicerone_started")
  app$wait_for_idle()

  started <- input_value(app, "e2e_step_highlighted_cicerone_started")
  expect_equal(started$index, 0)

  state <- input_value(app, "e2e_step_highlighted_cicerone_state")
  expect_false(is.null(state))
  expect_equal(state$highlighted, "el1")

  # "highlighted" is emitted after "started" for the very same highlight
  # (see highlightBookkeeping() in steps.js), so the latest value of the
  # unified event stream is "highlighted" by the time _started has fired
  event <- input_value(app, "e2e_step_highlighted_cicerone_event")
  expect_equal(event$type, "highlighted")
})

test_that("a hint's on_button_click still auto-dismisses the hint", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_show_hints_button")
  app$wait_for_js("document.querySelector('.driver-hint') !== null")

  app$click(selector = ".driver-hint")
  app$wait_for_value(input = "e2e_hints_button_cicerone_hint_opened")

  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_hints_button_cicerone_hint_button")
  app$wait_for_value(input = "e2e_hints_button_cicerone_hint_dismissed")

  hb <- input_value(app, "e2e_hints_button_cicerone_hint_button")
  hd <- input_value(app, "e2e_hints_button_cicerone_hint_dismissed")
  expect_equal(hb$element, "el1")
  expect_equal(hd$element, "el1")

  expect_true(app$get_js(
    "(function(){
      var el = document.querySelector('.driver-popover');
      return !el || getComputedStyle(el).display === 'none';
    })()"
  ))
})
