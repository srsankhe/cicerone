# WP6 end-to-end coverage: `advance_on` (a named DOM event on any
# element) and `advance_when` (a re-evaluated JavaScript predicate), both
# driven through a real browser via shinytest2/chromote. Skipped unless
# CICERONE_E2E=true (see helper-e2e.R for the install requirement this
# implies).
#
# `_cicerone_event` is asserted through the fixture's `adv_event_log`
# export rather than `input_value(app, "e2e_adv_cicerone_event")`:
# `advance_on` deliberately emits `event:"advance"` immediately before a
# `moveNext()` that itself emits `event:"highlighted"` a frame later, and
# `app$wait_for_value()` polls the *current* value of an input, so it can
# observe the second value and never see the first. The server-side
# accumulator (same idea as WP1's `event_log`, see app.R) cannot miss one.

# Not in helper-e2e.R (out of WP6's file scope): a small local assertion
# used by every test in this file.
expect_no_console_errors <- function(app) {
  logs <- app$get_logs()
  errors <- logs[logs$location == "chromote" & logs$level == "error", ]
  testthat::expect_equal(nrow(errors), 0)
}

adv_events <- function(app) {
  strsplit(app$get_value(export = "adv_event_log"), ",")[[1]]
}

test_that("advance_on: clicking the trigger element advances the tour and emits an advance event", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_adv")
  app$wait_for_value(input = "e2e_adv_cicerone_state")
  state0 <- input_value(app, "e2e_adv_cicerone_state")
  expect_equal(state0$index, 0)

  app$click(selector = "#trigger")
  app$wait_for_value(input = "e2e_adv_cicerone_state", ignore = list(state0))
  state1 <- input_value(app, "e2e_adv_cicerone_state")
  expect_equal(state1$index, 1)

  expect_equal(
    adv_events(app),
    c("started:el1", "highlighted:el1", "advance:trigger", "highlighted:el2")
  )

  expect_no_console_errors(app)
})

test_that("advance_on: clicking the trigger on a step without advance_on does nothing", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_adv")
  app$wait_for_value(input = "e2e_adv_cicerone_state")
  state0 <- input_value(app, "e2e_adv_cicerone_state")

  app$click(selector = "#trigger")
  app$wait_for_value(input = "e2e_adv_cicerone_state", ignore = list(state0))
  state1 <- input_value(app, "e2e_adv_cicerone_state")
  expect_equal(state1$index, 1)

  # step 2 has no advance_on: clicking #trigger again must be a no-op
  app$click(selector = "#trigger")
  app$wait_for_idle()
  state_after <- input_value(app, "e2e_adv_cicerone_state")
  expect_equal(state_after$index, 1)

  expect_equal(
    adv_events(app),
    c("started:el1", "highlighted:el1", "advance:trigger", "highlighted:el2")
  )

  expect_no_console_errors(app)
})

test_that("advance_on: moving back to the step re-arms the listener", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_adv")
  app$wait_for_value(input = "e2e_adv_cicerone_state")
  state0 <- input_value(app, "e2e_adv_cicerone_state")

  app$click(selector = "#trigger")
  app$wait_for_value(input = "e2e_adv_cicerone_state", ignore = list(state0))
  state1 <- input_value(app, "e2e_adv_cicerone_state")
  expect_equal(state1$index, 1)

  app$click(selector = ".driver-popover-prev-btn")
  app$wait_for_value(input = "e2e_adv_cicerone_state", ignore = list(state1))
  state_back <- input_value(app, "e2e_adv_cicerone_state")
  expect_equal(state_back$index, 0)

  app$click(selector = "#trigger")
  app$wait_for_value(input = "e2e_adv_cicerone_state", ignore = list(state_back))
  state_readvanced <- input_value(app, "e2e_adv_cicerone_state")
  expect_equal(state_readvanced$index, 1)

  expect_equal(
    adv_events(app),
    c(
      "started:el1", "highlighted:el1", "advance:trigger", "highlighted:el2",
      "previous:el2", "highlighted:el1", "advance:trigger", "highlighted:el2"
    )
  )

  expect_no_console_errors(app)
})

test_that("advance_when: typing alone does not advance, checking the box does", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_adv")
  app$wait_for_value(input = "e2e_adv_cicerone_state")
  state0 <- input_value(app, "e2e_adv_cicerone_state")

  # step 1 -> step 2 (advance_on), step 2 -> step 3 (plain Next click)
  app$click(selector = "#trigger")
  app$wait_for_value(input = "e2e_adv_cicerone_state", ignore = list(state0))
  state1 <- input_value(app, "e2e_adv_cicerone_state")
  expect_equal(state1$index, 1)

  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_adv_cicerone_state", ignore = list(state1))
  state2 <- input_value(app, "e2e_adv_cicerone_state")
  expect_equal(state2$index, 2)

  # typing into #adv_name alone must not advance: dispatch a real "input"
  # event (matching how a user typing produces one), not
  # app$set_inputs(), which drives Shiny's binding through jQuery and
  # never reaches a plain document-level `addEventListener("input", ...)`
  app$run_js(
    "(function(){
      var el = document.querySelector('#adv_name');
      el.value = 'a name';
      el.dispatchEvent(new Event('input', {bubbles: true}));
    })()"
  )
  app$wait_for_idle()
  expect_true(app$get_js("document.querySelector('.driver-popover') !== null"))
  expect_equal(input_value(app, "e2e_adv_cicerone_state")$index, 2)

  # checking #adv_parsed completes the predicate; a native click (not
  # set_inputs()) so the checkbox's default activation behaviour fires a
  # real "change" event that a document-level listener can see
  app$click(selector = "#adv_parsed")
  # step 3 is the tour's last step: driver.js's own moveNext() (called by
  # the advance handler) has no step to move to, so it destroys the tour
  # directly rather than routing through onDoneClick -- see wp6-report.md
  # for the driver.js evidence. `_ended` is therefore the reliable signal
  # that the predicate fired and the tour reacted to it.
  app$wait_for_value(input = "e2e_adv_cicerone_ended")

  # advancing off the last step completes the tour
  expect_equal(input_value(app, "e2e_adv_cicerone_ended")$reason, "done")
  expect_true("advance:el3" %in% adv_events(app))
  expect_true(app$get_js(
    "(function(){
      var el = document.querySelector('.driver-popover');
      return !el || getComputedStyle(el).display === 'none';
    })()"
  ))

  expect_no_console_errors(app)
})

test_that("$reset() mid-step-1 disarms the advance listener without throwing", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_adv")
  app$wait_for_value(input = "e2e_adv_cicerone_state")

  app$click(input = "btn_reset_adv")
  app$wait_for_value(input = "e2e_adv_cicerone_ended")

  expect_null(app$get_js("window.cicerone.advanceListeners['e2e_adv']"))

  # clicking #trigger after reset must not throw (no listener left armed)
  app$click(selector = "#trigger")
  app$wait_for_idle()

  expect_null(app$get_js("window.cicerone.advanceListeners['e2e_adv']"))
  expect_no_console_errors(app)
})
