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

test_that("initialise forwards every tour-level option Cicerone$new() has", {
  s <- make_session()

  initialise(
    "man5",
    allow_scroll = FALSE,
    disable_active_interaction = TRUE,
    advance_on_click = TRUE,
    skip_missing_element = TRUE,
    wait_for_element = 2000,
    disable_buttons = "close",
    show_progress = TRUE,
    progress_text = "{{current}} of {{total}}",
    duration = 400,
    on_popover_render = "function(popover, opts){}",
    on_highlight_started = "function(element, step, opts){}",
    on_highlighted = "function(element, step, opts){}",
    on_deselected = "function(element, step, opts){}",
    on_destroy_started = "function(element, step, opts){}",
    on_destroyed = "function(element, step, opts){}",
    on_next_click = "function(element, step, opts){}",
    on_prev_click = "function(element, step, opts){}",
    on_close_click = "function(element, step, opts){}",
    on_done_click = "function(element, step, opts){}",
    session = s
  )

  gl <- s$msgs[[1]]$message$globals

  expect_false(gl$allowScroll)
  expect_true(gl$disableActiveInteraction)
  expect_true(gl$advanceOnClick)
  expect_true(gl$skipMissingElement)
  expect_equal(gl$waitForElement, 2000)
  expect_equal(gl$disableButtons, list("close"))
  expect_true(gl$showProgress)
  expect_equal(gl$progressText, "{{current}} of {{total}}")
  expect_equal(gl$duration, 400)
  expect_type(gl$onPopoverRender, "character")
  expect_type(gl$onHighlightStarted, "character")
  expect_type(gl$onHighlighted, "character")
  expect_type(gl$onDeselected, "character")
  expect_type(gl$onDestroyStarted, "character")
  expect_type(gl$onDestroyed, "character")
  expect_type(gl$onNextClick, "character")
  expect_type(gl$onPrevClick, "character")
  expect_type(gl$onCloseClick, "character")
  expect_type(gl$onDoneClick, "character")
})

test_that("highlight forwards every step/popover-level option $step() has", {
  s <- make_session()

  highlight(
    "plot", "man6",
    show_progress = TRUE,
    progress_text = "{{current}} of {{total}}",
    on_popover_render = "function(popover, opts){}",
    on_next = "function(element, step, opts){}",
    on_prev = "function(element, step, opts){}",
    on_close = "function(element, step, opts){}",
    on_done = "function(element, step, opts){}",
    disable_active_interaction = TRUE,
    advance_on_click = TRUE,
    skip_missing_element = TRUE,
    wait_for_element = 1500,
    data = list(foo = "bar"),
    session = s
  )

  msg <- s$msgs[[1]]$message

  expect_true(msg$popover$showProgress)
  expect_equal(msg$popover$progressText, "{{current}} of {{total}}")
  expect_type(msg$popover$onPopoverRender, "character")
  expect_type(msg$popover$onNextClick, "character")
  expect_type(msg$popover$onPrevClick, "character")
  expect_type(msg$popover$onCloseClick, "character")
  expect_type(msg$popover$onDoneClick, "character")
  expect_true(msg$disableActiveInteraction)
  expect_true(msg$advanceOnClick)
  expect_true(msg$skipMissingElement)
  expect_equal(msg$waitForElement, 1500)
  expect_equal(msg$data$foo, "bar")
})

test_that("initialise()'s progress_style is sent only when not the default", {
  s <- make_session()
  initialise("man1", session = s)
  expect_null(s$msgs[[1]]$message$globals$progressStyle)

  s2 <- make_session()
  initialise("man2", progress_style = "bar", session = s2)
  globals <- s2$msgs[[1]]$message$globals
  expect_equal(globals$progressStyle, "bar")
  expect_true(globals$showProgress)
})

test_that("initialise()'s invalid progress_style errors", {
  expect_error(initialise("man", progress_style = "spinner"))
})

test_that("highlight()'s progress_style is sent verbatim and forces show_progress on", {
  s <- make_session()
  highlight("plot", "man", progress_style = "dots", session = s)

  popover <- s$msgs[[1]]$message$popover
  expect_equal(popover$progressStyle, "dots")
  expect_true(popover$showProgress)
})

test_that("highlight()'s invalid progress_style errors", {
  expect_error(highlight("plot", "man", progress_style = "spinner", session = make_session()))
})

test_that("initialise's formals match Cicerone$new() apart from a documented allowlist", {
  # `mathjax` is a Cicerone-only convenience that wraps each step's
  # `on_highlighted` hook for MathJax typesetting; the functional API has
  # no per-step loop to wrap into, so it has no `initialise()` equivalent.
  # `exclusive`/`wait_for_visible` (WP7) gate `cicerone-start`, a message
  # `initialise()`'s single-highlight ("cicerone-highlight-man") path
  # never sends; scoped to Cicerone$new()/$step() only, see NEWS.
  # `persist`/`version` (WP5) need a stable object to read/write a
  # record against and to run `$forget()`/`$start(resume = )` on later;
  # `initialise()` keeps no such object between calls, so persistence
  # is Cicerone-only, see NEWS.
  allowlist <- c("mathjax", "exclusive", "wait_for_visible", "persist", "version")

  extra <- setdiff(
    names(formals(Cicerone$public_methods$initialize)),
    names(formals(initialise))
  )

  expect_equal(sort(extra), sort(allowlist))
})
