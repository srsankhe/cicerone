test_that("functional API falls back to the default reactive domain", {
  s <- make_session()

  shiny::withReactiveDomain(s, {
    initialise("man2")
    highlight("plot", "man2", title = "T")
  })

  expect_equal(s$msgs[[1]]$type, "cicerone-init")
  expect_equal(s$msgs[[1]]$message$id, "man2")
  expect_equal(s$msgs[[2]]$type, "cicerone-highlight-man")
  expect_equal(s$msgs[[2]]$message$element, "#plot")
})

test_that("functional API warns on removed driver.js options", {
  s <- make_session()

  expect_warning(
    initialise("man3", close_btn_text = "Close", session = s),
    "close_btn_text"
  )
  expect_warning(
    initialise("man3", stage_background = "#fff", session = s),
    "stage_background"
  )
  expect_warning(
    highlight("plot", "man3", close_btn_text = "Close", session = s),
    "close_btn_text"
  )
})

test_that("initialise maps overlay_click_next", {
  s <- make_session()
  initialise("man4", overlay_click_next = TRUE, session = s)
  expect_equal(
    s$msgs[[1]]$message$globals$overlayClickBehavior,
    "nextStep"
  )
})
