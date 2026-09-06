# WP7 end-to-end coverage: `exclusive` (default TRUE), `destroy_all()`, and
# a NAS-shape reproduction of chaining a second tour's `$start()` off a
# click on the first tour's last-step element. Driven through a real
# browser via shinytest2/chromote. Skipped unless CICERONE_E2E=true (see
# helper-e2e.R for the install requirement this implies).

test_that("starting a second tour supersedes the first one (exclusive default)", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")

  app$click(input = "btn_start_b")
  app$wait_for_value(input = "e2e_b_cicerone_started")
  app$wait_for_idle()

  expect_equal(app$get_js("document.querySelectorAll('.driver-popover').length"), 1)
  expect_equal(app$get_js("document.querySelectorAll('.driver-overlay').length"), 1)

  ended <- input_value(app, "e2e_cicerone_ended")
  expect_equal(ended$reason, "superseded")

  started_b <- input_value(app, "e2e_b_cicerone_started")
  expect_equal(started_b$index, 0)
})

test_that("exclusive = FALSE does not supersede an already active tour", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")

  app$click(input = "btn_start_nonexcl")
  app$wait_for_value(input = "e2e_nonexcl_cicerone_state")
  app$wait_for_idle()

  # documents driver.js's own behaviour: two live Driver instances, two
  # popovers, two overlays -- cicerone does not prevent this when the
  # *starting* tour opts out with exclusive = FALSE.
  expect_equal(app$get_js("document.querySelectorAll('.driver-popover').length"), 2)
  expect_null(input_value(app, "e2e_cicerone_ended"))
})

test_that("destroy_all() destroys every active tour with reason programmatic", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")
  app$click(input = "btn_start_nonexcl")
  app$wait_for_value(input = "e2e_nonexcl_cicerone_state")
  app$wait_for_idle()
  expect_equal(app$get_js("document.querySelectorAll('.driver-popover').length"), 2)

  app$click(input = "btn_destroy_all")
  app$wait_for_value(input = "e2e_cicerone_ended")
  app$wait_for_value(input = "e2e_nonexcl_cicerone_ended")
  app$wait_for_idle()

  expect_equal(app$get_js("document.querySelectorAll('.driver-popover').length"), 0)
  expect_equal(input_value(app, "e2e_cicerone_ended")$reason, "programmatic")
  expect_equal(input_value(app, "e2e_nonexcl_cicerone_ended")$reason, "programmatic")
})

test_that("NAS-shape reproduction: a click observer chaining to a second tour's $start() supersedes cleanly", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_chain")
  app$wait_for_value(input = "e2e_chain_cicerone_state")
  state0 <- input_value(app, "e2e_chain_cicerone_state")

  # move to the chain's last step, which highlights #chain_trigger
  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_chain_cicerone_state", ignore = list(state0))
  state1 <- input_value(app, "e2e_chain_cicerone_state")
  expect_equal(state1$highlighted, "chain_trigger")

  # click the highlighted element itself (not a popover button): this is
  # a real Shiny actionButton click, picked up by the `input$chain_trigger`
  # observer in the fixture, which calls e2e_b$start() -- modelling
  # WP6's not-yet-available `advance_on` with a plain observer.
  app$click(selector = "#chain_trigger")
  app$wait_for_value(input = "e2e_b_cicerone_started")
  app$wait_for_idle()

  expect_equal(app$get_js("document.querySelectorAll('.driver-popover').length"), 1)

  b_state <- input_value(app, "e2e_b_cicerone_state")
  expect_equal(b_state$index, 0)

  chain_log <- strsplit(app$get_value(export = "chain_event_log"), ",")[[1]]
  b_log <- strsplit(app$get_value(export = "b_event_log"), ",")[[1]]
  expect_false("start_failed" %in% chain_log)
  expect_false("start_failed" %in% b_log)
})
