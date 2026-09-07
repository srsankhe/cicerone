# WP9 end-to-end coverage: progress bar/dots variants and CSS theming,
# driven through a real browser via shinytest2/chromote. Skipped unless
# CICERONE_E2E=true (see helper-e2e.R for the install requirement this
# implies).

# Read a `.driver-popover`-scoped CSS custom property's computed value.
progress_var <- function(app, name) {
  app$get_js(sprintf(
    "getComputedStyle(document.querySelector('.driver-popover')).getPropertyValue('%s').trim()",
    name
  ))
}

popover_style <- function(app, selector, prop) {
  app$get_js(sprintf(
    "getComputedStyle(document.querySelector('%s'))['%s']", selector, prop
  ))
}

test_that("progress_style = 'bar' adds the class and sets current/total, updated on Next", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_bar")
  app$wait_for_value(input = "e2e_bar_cicerone_state")

  expect_true(app$get_js(
    "document.querySelector('.driver-popover').classList.contains('cicerone-progress-bar')"
  ))
  expect_equal(progress_var(app, "--cicerone-progress-current"), "1")
  expect_equal(progress_var(app, "--cicerone-progress-total"), "3")

  state0 <- input_value(app, "e2e_bar_cicerone_state")
  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_bar_cicerone_state", ignore = list(state0))
  expect_equal(progress_var(app, "--cicerone-progress-current"), "2")
  expect_equal(progress_var(app, "--cicerone-progress-total"), "3")

  state1 <- input_value(app, "e2e_bar_cicerone_state")
  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_bar_cicerone_state", ignore = list(state1))
  expect_equal(progress_var(app, "--cicerone-progress-current"), "3")
  expect_equal(progress_var(app, "--cicerone-progress-total"), "3")
})

test_that("progress_style = 'dots' adds the class and sets current/total", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_dots")
  app$wait_for_value(input = "e2e_dots_cicerone_state")

  expect_true(app$get_js(
    "document.querySelector('.driver-popover').classList.contains('cicerone-progress-dots')"
  ))
  expect_equal(progress_var(app, "--cicerone-progress-current"), "1")
  expect_equal(progress_var(app, "--cicerone-progress-total"), "3")

  state0 <- input_value(app, "e2e_dots_cicerone_state")
  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_value(input = "e2e_dots_cicerone_state", ignore = list(state0))
  expect_equal(progress_var(app, "--cicerone-progress-current"), "2")
})

test_that("a standalone highlight() with progress_style = 'bar' still renders the bar", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  # Copilot review item F: `id = "e2e_adhoc"` has no preceding
  # initialise()/$init() -- the ad hoc driver.js instance
  # cicerone-highlight-man creates on first use must still wrap its
  # config-level onPopoverRender (see tour.js) for the bar to render.
  app$click(input = "btn_highlight_adhoc")
  app$wait_for_js("document.querySelector('.driver-popover') !== null")

  expect_true(app$get_js(
    "document.querySelector('.driver-popover').classList.contains('cicerone-progress-bar')"
  ))
})

test_that("cicerone_theme(accent, selector = '.e2e-themed') recolors only the themed tour's Next button", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_themed")
  app$wait_for_value(input = "e2e_themed_cicerone_state")

  expect_equal(
    popover_style(app, ".driver-popover-next-btn", "backgroundColor"),
    "rgb(255, 0, 0)"
  )

  app$click(selector = ".driver-popover-close-btn")
  app$wait_for_value(input = "e2e_themed_cicerone_ended")

  # untouched by the ".e2e-themed"-scoped theme
  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")
  expect_equal(
    popover_style(app, ".driver-popover-next-btn", "backgroundColor"),
    "rgb(255, 255, 255)"
  )
})

test_that("default look (no progress_style, no theme) is unchanged", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")

  # recorded from a clean install of the feat/wp2-api-parity base commit,
  # before any WP9 CSS/JS change -- see the WP9 report for how these were
  # captured
  expect_equal(popover_style(app, ".driver-popover", "backgroundColor"), "rgb(255, 255, 255)")
  expect_equal(popover_style(app, ".driver-popover", "color"), "rgb(45, 45, 45)")
  expect_equal(popover_style(app, ".driver-popover", "borderRadius"), "5px")
  expect_equal(popover_style(app, ".driver-popover", "fontSize"), "14px")

  expect_equal(popover_style(app, ".driver-popover-title", "backgroundColor"), "rgba(0, 0, 0, 0)")
  expect_equal(popover_style(app, ".driver-popover-title", "color"), "rgb(45, 45, 45)")
  expect_equal(popover_style(app, ".driver-popover-title", "borderRadius"), "0px")
  expect_equal(popover_style(app, ".driver-popover-title", "fontSize"), "19px")

  expect_equal(popover_style(app, ".driver-popover-description", "backgroundColor"), "rgba(0, 0, 0, 0)")
  expect_equal(popover_style(app, ".driver-popover-description", "color"), "rgb(45, 45, 45)")
  expect_equal(popover_style(app, ".driver-popover-description", "borderRadius"), "0px")
  expect_equal(popover_style(app, ".driver-popover-description", "fontSize"), "14px")

  expect_equal(popover_style(app, ".driver-popover-next-btn", "backgroundColor"), "rgb(255, 255, 255)")
  expect_equal(popover_style(app, ".driver-popover-next-btn", "color"), "rgb(45, 45, 45)")
  expect_equal(popover_style(app, ".driver-popover-next-btn", "borderRadius"), "3px")
  expect_equal(popover_style(app, ".driver-popover-next-btn", "fontSize"), "12px")
})
