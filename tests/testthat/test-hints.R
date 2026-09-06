test_that("hints build and send the right messages", {
  s <- make_session()

  h <- Hints$new(id = "h", button_text = "Got it", overlay = TRUE)$hint(
    "plot", title = "Hint", description = "A hint",
    hint_id = "p1", beacon_side = "top"
  )

  h$init(session = s)
  msg <- s$msgs[[1]]
  expect_equal(msg$type, "cicerone-hints-init")
  expect_equal(msg$message$config$buttonText, "Got it")
  expect_true(msg$message$config$overlay)
  expect_equal(msg$message$hints[[1]]$element, "#plot")
  expect_equal(msg$message$hints[[1]]$id, "p1")
  expect_equal(msg$message$hints[[1]]$beacon$side, "top")
  expect_equal(msg$message$hints[[1]]$popover$title, "Hint")

  h$show(session = s)
  expect_equal(s$msgs[[2]]$type, "cicerone-hints-show")

  h$open("p1", session = s)
  expect_equal(s$msgs[[3]]$type, "cicerone-hints-open")
  expect_equal(s$msgs[[3]]$message$hint, "p1")

  h$dismiss(1, session = s)
  expect_equal(s$msgs[[4]]$type, "cicerone-hints-dismiss")
  expect_equal(s$msgs[[4]]$message$hint, 0)

  h$restore(1, session = s)
  expect_equal(s$msgs[[5]]$message$hint, 0)

  h$close(session = s)
  h$hide(session = s)
  h$refresh(session = s)
  expect_equal(s$msgs[[6]]$type, "cicerone-hints-close")
  expect_equal(s$msgs[[7]]$type, "cicerone-hints-hide")
  expect_equal(s$msgs[[8]]$type, "cicerone-hints-refresh")
})

test_that("hint requires el", {
  expect_error(Hints$new()$hint())
})

test_that("hint forwards on_popover_render to popover.onPopoverRender", {
  s <- make_session()
  h <- Hints$new(id = "hp")$hint(
    "plot", title = "x", on_popover_render = "function(popover, opts){}"
  )
  h$init(session = s)

  expect_type(s$msgs[[1]]$message$hints[[1]]$popover$onPopoverRender, "character")
})

test_that("global beacon options land in the config", {
  s <- make_session()
  h <- Hints$new(
    id = "hb", beacon_side = "left", beacon_align = "end",
    beacon_animate = FALSE, beacon_class = "my-beacon"
  )$hint("plot", title = "x")
  h$init(session = s)

  beacon <- s$msgs[[1]]$message$config$beacon
  expect_equal(beacon$side, "left")
  expect_equal(beacon$align, "end")
  expect_false(beacon$animate)
  expect_equal(beacon$className, "my-beacon")
})

test_that("hint methods fall back to the default reactive domain", {
  s <- make_session()
  h <- Hints$new(id = "hd")$hint("plot", title = "x", hint_id = "p1")

  shiny::withReactiveDomain(s, {
    h$init()
    h$show()
    h$hide()
    h$open(1)
    h$close()
    h$dismiss(1)
    h$restore(1)
    h$refresh()
  })

  types <- vapply(s$msgs, `[[`, character(1), "type")
  expect_equal(types, c(
    "cicerone-hints-init", "cicerone-hints-show", "cicerone-hints-hide",
    "cicerone-hints-open", "cicerone-hints-close", "cicerone-hints-dismiss",
    "cicerone-hints-restore", "cicerone-hints-refresh"
  ))
})
