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

test_that("advance_on: string and list forms normalise to the same payload", {
  s <- make_session()
  g <- Cicerone$new(id = "adv1")$
    step("el1", title = "x", advance_on = "#trigger")$
    step("el2", title = "y", advance_on = list(el = "#trigger", event = "input"))
  g$init(session = s)

  st <- s$msgs[[1]]$message$steps
  expect_equal(st[[1]]$advanceOn, list(element = "#trigger", event = "click"))
  expect_equal(st[[2]]$advanceOn, list(element = "#trigger", event = "input"))
})

test_that("advance_on: list(el=) without event defaults to click", {
  g <- Cicerone$new()$step("el1", title = "x", advance_on = list(el = "trigger"))
  expect_equal(
    g$get_steps()[[1]]$advanceOn,
    list(element = "#trigger", event = "click")
  )
})

test_that("advance_on: a non-string event errors", {
  expect_error(
    Cicerone$new()$step(
      "el1", title = "x", advance_on = list(el = "#trigger", event = 1)
    )
  )
  expect_error(
    Cicerone$new()$step("el1", title = "x", advance_on = list(event = "click"))
  )
})

test_that("advance_when lands as advanceWhen", {
  g <- Cicerone$new()$step(
    "el1", title = "x",
    advance_when = "() => document.querySelector('#x').checked"
  )
  expect_equal(
    g$get_steps()[[1]]$advanceWhen,
    "() => document.querySelector('#x').checked"
  )
})

test_that("advance_when: a non-string predicate errors", {
  expect_error(Cicerone$new()$step("el1", title = "x", advance_when = TRUE))
})

test_that("highlight(advance_on=) payload", {
  s <- make_session()
  highlight(
    "plot", "man_adv", advance_on = list(el = "#trigger", event = "input"),
    session = s
  )
  expect_equal(
    s$msgs[[1]]$message$advanceOn,
    list(element = "#trigger", event = "input")
  )
})

test_that("highlight(advance_when=) payload", {
  s <- make_session()
  highlight(
    "plot", "man_adv2", advance_when = "() => true", session = s
  )
  expect_equal(s$msgs[[1]]$message$advanceWhen, "() => true")
})

# WP9 -------------------------------------------------------------------

test_that("progress_style defaults to text and is not sent", {
  s <- make_session()
  g <- Cicerone$new(id = "pg1")$step("plot", title = "x")
  g$init(session = s)

  gl <- s$msgs[[1]]$message$globals
  expect_null(gl$progressStyle)
  expect_false(isTRUE(gl$showProgress))
})

test_that("tour-level progress_style is sent and forces show_progress on", {
  s <- make_session()
  g <- Cicerone$new(id = "pg2", progress_style = "bar")$step("plot", title = "x")
  g$init(session = s)

  gl <- s$msgs[[1]]$message$globals
  expect_equal(gl$progressStyle, "bar")
  expect_true(gl$showProgress)
})

test_that("tour-level progress_style = 'dots' is sent verbatim", {
  s <- make_session()
  g <- Cicerone$new(id = "pg3", progress_style = "dots")$step("plot", title = "x")
  g$init(session = s)

  expect_equal(s$msgs[[1]]$message$globals$progressStyle, "dots")
})

test_that("an explicit show_progress = FALSE is overridden by bar/dots", {
  s <- make_session()
  g <- Cicerone$new(
    id = "pg4", progress_style = "bar", show_progress = FALSE
  )$step("plot", title = "x")
  g$init(session = s)

  expect_true(s$msgs[[1]]$message$globals$showProgress)
})

test_that("an invalid tour-level progress_style errors", {
  expect_error(Cicerone$new(progress_style = "spinner"))
})

test_that("step-level progress_style overrides the tour's default", {
  s <- make_session()
  g <- Cicerone$
    new(id = "pg5", progress_style = "bar")$
    step("plot", title = "x")$
    step("table", title = "y", progress_style = "text")
  g$init(session = s)

  st <- s$msgs[[1]]$message$steps
  expect_null(st[[1]]$popover$progressStyle)
  expect_equal(st[[2]]$popover$progressStyle, "text")
  # the overriding step's own show_progress is untouched by "text"
  expect_null(st[[2]]$popover$showProgress)
})

test_that("step-level progress_style = 'dots' forces show_progress on for that step", {
  s <- make_session()
  g <- Cicerone$
    new(id = "pg6")$
    step("plot", title = "x", progress_style = "dots")
  g$init(session = s)

  st <- s$msgs[[1]]$message$steps
  expect_equal(st[[1]]$popover$progressStyle, "dots")
  expect_true(st[[1]]$popover$showProgress)
  # the tour-level default is untouched (still "text", not sent)
  expect_null(s$msgs[[1]]$message$globals$progressStyle)
})

test_that("an invalid step-level progress_style errors", {
  expect_error(Cicerone$new()$step("plot", title = "x", progress_style = "spinner"))
})
# --- WP7 begin: exclusive / wait_for_visible / destroy_all unit tests ---

test_that("exclusive defaults to TRUE in the init payload", {
  s <- make_session()
  g <- Cicerone$new(id = "wp7_excl_default")$step("plot", title = "x")
  g$init(session = s)

  expect_true(s$msgs[[1]]$message$globals$exclusive)
})

test_that("exclusive = FALSE is forwarded to the init payload", {
  s <- make_session()
  g <- Cicerone$new(id = "wp7_excl_false", exclusive = FALSE)$step("plot", title = "x")
  g$init(session = s)

  expect_false(s$msgs[[1]]$message$globals$exclusive)
})

test_that("wait_for_visible lands at tour and step level", {
  s <- make_session()
  g <- Cicerone$new(
    id = "wp7_wfv", wait_for_visible = 2000
  )$step(
    "plot", title = "x", wait_for_visible = 500
  )$step(
    "table", title = "y"
  )
  g$init(session = s)

  gl <- s$msgs[[1]]$message$globals
  st <- s$msgs[[1]]$message$steps
  expect_equal(gl$waitForVisible, 2000)
  expect_equal(st[[1]]$waitForVisible, 500)
  expect_null(st[[2]]$waitForVisible)
})

test_that("destroy_all() sends cicerone-destroy-all", {
  s <- make_session()
  destroy_all(session = s)

  expect_equal(s$msgs[[1]]$type, "cicerone-destroy-all")
})

test_that("destroy_all() falls back to the default reactive domain", {
  s <- make_session()
  shiny::withReactiveDomain(s, destroy_all())

  expect_equal(s$msgs[[1]]$type, "cicerone-destroy-all")
})
# --- WP7 end ---
