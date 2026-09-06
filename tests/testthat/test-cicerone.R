test_that("legacy arguments map to driver.js 1.x config", {
  s <- make_session()

  g <- Cicerone$new(
    opacity = .5, padding = 5, overlay_click_next = TRUE,
    show_btns = TRUE, keyboard_control = FALSE, id = "guide"
  )$step(
    "plot", title = "Plot", description = "A plot", position = "left-center"
  )$step(
    el = "table", title = "Table", position = "top-right",
    on_next = "function(){}"
  )

  g$init(session = s)
  msg <- s$msgs[[1]]
  expect_equal(msg$type, "cicerone-init")

  gl <- msg$message$globals
  expect_equal(gl$overlayOpacity, .5)
  expect_equal(gl$stagePadding, 5)
  expect_equal(gl$overlayClickBehavior, "nextStep")
  expect_false(gl$allowKeyboardControl)
  expect_equal(gl$showButtons, list("next", "previous", "close"))
  expect_equal(gl$id, "guide")

  st <- msg$message$steps
  expect_equal(st[[1]]$element, "#plot")
  expect_equal(st[[1]]$popover$side, "left")
  expect_equal(st[[1]]$popover$align, "center")
  expect_equal(st[[2]]$popover$side, "top")
  expect_equal(st[[2]]$popover$align, "end")
  expect_type(st[[2]]$popover$onNextClick, "character")
})

test_that("removed driver.js options warn", {
  expect_warning(Cicerone$new(close_btn_text = "Close"), "close_btn_text")
  expect_warning(Cicerone$new(stage_background = "#fff"), "stage_background")
})

test_that("new driver.js 1.x options are forwarded", {
  s <- make_session()

  g <- Cicerone$new(
    id = "g2", show_progress = TRUE, progress_text = "{{current}}/{{total}}",
    overlay_color = "#000", stage_radius = 8, smooth_scroll = TRUE,
    popover_class = "my-theme", disable_buttons = "close",
    on_destroyed = "function(){}"
  )$step(
    "plot", title = "P", side = "bottom", align = "end",
    show_progress = TRUE, done_btn_text = "Finish",
    on_deselected = "function(){}", data = list(foo = "bar"),
    wait_for_element = 1000, skip_missing_element = TRUE
  )$step(
    title = "Modal step", description = "No element"
  )
  g$init(session = s)

  gl <- s$msgs[[1]]$message$globals
  expect_true(gl$showProgress)
  expect_equal(gl$progressText, "{{current}}/{{total}}")
  expect_equal(gl$overlayColor, "#000")
  expect_equal(gl$stageRadius, 8)
  expect_true(gl$smoothScroll)
  expect_equal(gl$popoverClass, "my-theme")
  expect_equal(gl$disableButtons, list("close"))
  expect_type(gl$onDestroyed, "character")

  st <- s$msgs[[1]]$message$steps
  expect_equal(st[[1]]$popover$side, "bottom")
  expect_equal(st[[1]]$popover$align, "end")
  expect_equal(st[[1]]$popover$doneBtnText, "Finish")
  expect_equal(st[[1]]$data$foo, "bar")
  expect_equal(st[[1]]$waitForElement, 1000)
  expect_true(st[[1]]$skipMissingElement)
  # element-less (modal) step
  expect_null(st[[2]]$element)
  expect_equal(st[[2]]$popover$title, "Modal step")
})

test_that("methods send the right messages", {
  s <- make_session()
  g <- Cicerone$new(id = "g3")$step("plot", title = "x")
  g$init(session = s)

  g$start(session = s)
  expect_equal(s$msgs[[2]]$type, "cicerone-start")
  expect_equal(s$msgs[[2]]$message$step, 0)

  g$move_to(2, session = s)
  expect_equal(s$msgs[[3]]$type, "cicerone-move-to")
  expect_equal(s$msgs[[3]]$message$step, 1)

  g$move_forward(session = s)
  expect_equal(s$msgs[[4]]$type, "cicerone-next")

  g$move_backward(session = s)
  expect_equal(s$msgs[[5]]$type, "cicerone-previous")

  g$refresh(session = s)
  expect_equal(s$msgs[[6]]$type, "cicerone-refresh")

  g$highlight("plot", session = s)
  expect_equal(s$msgs[[7]]$type, "cicerone-highlight")
  expect_equal(s$msgs[[7]]$message$el, "#plot")

  g$destroy(session = s)
  expect_equal(s$msgs[[8]]$type, "cicerone-reset")

  g$reset(session = s)
  expect_equal(s$msgs[[9]]$type, "cicerone-reset")
})

test_that("run_once only starts the tour once", {
  s <- make_session()
  g <- Cicerone$new(id = "g4")$step("plot", title = "x")
  g$init(session = s, run_once = TRUE)
  g$start(session = s)
  g$start(session = s)
  starts <- vapply(s$msgs, function(m) m$type == "cicerone-start", logical(1))
  expect_equal(sum(starts), 1)
})

test_that("steps require an element or popover content", {
  expect_error(Cicerone$new()$step())
})

test_that("tab requires tab_id and vice versa", {
  expect_error(Cicerone$new()$step("x", tab = "t"))
  expect_error(Cicerone$new()$step("x", tab_id = "t"))
})

test_that("methods fall back to the default reactive domain", {
  s <- make_session()
  g <- Cicerone$new(id = "g5")$step("plot", title = "x")

  shiny::withReactiveDomain(s, {
    g$init()
    g$start()
    g$move_forward()
    g$move_backward()
    g$move_to(2)
    g$refresh()
    g$highlight("plot")
    g$reset()
  })

  types <- vapply(s$msgs, `[[`, character(1), "type")
  expect_equal(types, c(
    "cicerone-init", "cicerone-start", "cicerone-next",
    "cicerone-previous", "cicerone-move-to", "cicerone-refresh",
    "cicerone-highlight", "cicerone-reset"
  ))
})

test_that("state getters read Shiny inputs", {
  s <- make_session()
  s$input <- list(
    g6_cicerone_state = list(
      highlighted = "a", before_previous = "b", has_next = TRUE
    ),
    g6_cicerone_next = list(highlighted = "a"),
    g6_cicerone_previous = list(highlighted = "b")
  )
  g <- Cicerone$new(id = "g6")

  expect_equal(g$get_state(session = s)$highlighted, "a")
  expect_equal(g$get_next(session = s)$highlighted, "a")
  expect_equal(g$get_previous(session = s)$highlighted, "b")

  shiny::withReactiveDomain(s, {
    expect_true(g$get_state()$has_next)
    expect_equal(g$get_next()$highlighted, "a")
    expect_equal(g$get_previous()$highlighted, "b")
  })
})

test_that("get_started/get_ended read Shiny inputs", {
  s <- make_session()
  s$input <- list(
    g6b_cicerone_started = list(index = 0, total_steps = 3),
    g6b_cicerone_ended = list(
      reason = "done", completed = TRUE, index = 2, total_steps = 3
    )
  )
  g <- Cicerone$new(id = "g6b")

  expect_equal(g$get_started(session = s)$index, 0)
  expect_equal(g$get_started(session = s)$total_steps, 3)
  expect_equal(g$get_ended(session = s)$reason, "done")
  expect_true(g$get_ended(session = s)$completed)
  expect_equal(g$get_ended(session = s)$index, 2)

  shiny::withReactiveDomain(s, {
    expect_equal(g$get_started()$index, 0)
    expect_equal(g$get_ended()$reason, "done")
  })
})

test_that("deprecated getters warn and read from the state", {
  s <- make_session()
  s$input <- list(
    g7_cicerone_state = list(
      highlighted = "a", before_previous = "b", has_next = TRUE
    )
  )
  g <- Cicerone$new(id = "g7")

  expect_warning(hl <- g$get_highlighted_el(session = s), "get_state")
  expect_equal(hl, "a")
  expect_warning(prev <- g$get_previous_el(session = s), "get_state")
  expect_equal(prev, "b")
  expect_warning(nxt <- g$has_next_step(session = s), "get_state")
  expect_true(nxt)

  # no state yet: tour never highlighted anything
  empty <- make_session()
  expect_warning(hl <- g$get_highlighted_el(session = empty), "get_state")
  expect_null(hl)
  expect_warning(prev <- g$get_previous_el(session = empty), "get_state")
  expect_null(prev)
  expect_warning(nxt <- g$has_next_step(session = empty), "get_state")
  expect_null(nxt)
})

test_that("mathjax wraps on_highlighted", {
  s <- make_session()
  g <- Cicerone$new(id = "gm", mathjax = TRUE)$step(
    "plot", title = "x", on_highlighted = "console.log(1);"
  )
  g$init(session = s)

  on_highlighted <- s$msgs[[1]]$message$steps[[1]]$onHighlighted
  expect_match(on_highlighted, "MathJax", fixed = TRUE)
  expect_match(on_highlighted, "console.log(1);", fixed = TRUE)
})

test_that("is_id is deprecated", {
  expect_warning(
    Cicerone$new()$step("plot", title = "x", is_id = TRUE),
    "is_id"
  )
})

test_that("get_id and get_steps return what init sends", {
  s <- make_session()
  g <- Cicerone$new(id = "g8")$step("plot", title = "x")$step("table", title = "y")
  g$init(session = s)

  expect_equal(g$get_id(), "g8")
  expect_equal(g$get_steps(), s$msgs[[1]]$message$steps)
})

test_that("functional API maps arguments", {
  s <- make_session()

  initialise("man", opacity = .3, session = s)
  expect_equal(s$msgs[[1]]$type, "cicerone-init")
  expect_equal(s$msgs[[1]]$message$globals$overlayOpacity, .3)
  expect_equal(s$msgs[[1]]$message$id, "man")

  highlight("plot", "man", title = "T", position = "bottom-center", session = s)
  expect_equal(s$msgs[[2]]$type, "cicerone-highlight-man")
  expect_equal(s$msgs[[2]]$message$element, "#plot")
  expect_equal(s$msgs[[2]]$message$popover$side, "bottom")
  expect_equal(s$msgs[[2]]$message$popover$align, "center")
})
