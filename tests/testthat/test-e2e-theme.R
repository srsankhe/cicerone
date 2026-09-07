# WP10 end-to-end coverage: the new typography/layout `cicerone_theme()`
# arguments (font_family, title_size, title_weight, line_height,
# btn_font_size, btn_border, btn_radius, btn_hover_bg, max_width) and the
# extended `preset = "bootstrap"` mapping, driven through a real browser via
# shinytest2/chromote. Skipped unless CICERONE_E2E=true (see helper-e2e.R
# for the install requirement this implies).
#
# The default-look guardrail for these same properties lives in
# test-e2e-progress.R's "default look ... is unchanged" test, not here --
# this file only covers an explicit theme actually changing something.

popover_style <- function(app, selector, prop) {
  app$get_js(sprintf(
    "getComputedStyle(document.querySelector('%s'))['%s']", selector, prop
  ))
}

test_that("explicit font_family/title_size/btn_border override only the themed tour", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_typo")
  app$wait_for_value(input = "e2e_typo_cicerone_state")

  expect_true(grepl(
    "^Georgia", popover_style(app, ".driver-popover", "fontFamily")
  ))
  expect_equal(popover_style(app, ".driver-popover-title", "fontSize"), "24px")
  expect_equal(
    popover_style(app, ".driver-popover-next-btn", "borderTopColor"),
    "rgb(255, 0, 0)"
  )

  app$click(selector = ".driver-popover-close-btn")
  app$wait_for_value(input = "e2e_typo_cicerone_ended")

  # untouched by the ".e2e-typo"-scoped theme
  app$click(input = "btn_start")
  app$wait_for_value(input = "e2e_cicerone_state")
  expect_false(grepl(
    "^Georgia", popover_style(app, ".driver-popover", "fontFamily")
  ))
  expect_equal(popover_style(app, ".driver-popover-title", "fontSize"), "19px")
  expect_equal(
    popover_style(app, ".driver-popover-next-btn", "borderTopColor"),
    "rgb(204, 204, 204)"
  )
})

test_that("preset = 'bootstrap' makes the popover inherit the app's own font", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  body_font <- app$get_js("getComputedStyle(document.body).fontFamily")

  app$click(input = "btn_start_bs")
  app$wait_for_value(input = "e2e_bs_cicerone_state")

  expect_equal(popover_style(app, ".driver-popover", "fontFamily"), body_font)
})
