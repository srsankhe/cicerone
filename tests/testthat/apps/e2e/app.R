# Small, deterministic fixture app for the shinytest2 end-to-end harness
# (WP0, extended by WP1). Exercises the full Shiny <-> driver.js bridge: a
# 3-step tour that crosses a tabset and a module namespace, plus a one-hint
# Hints object, plus a handful of small single-step tours/hints exercising
# WP1's lifecycle inputs, reason detection and driver.js-parity edge cases.
#
# shinytest2 runs this app in a separate R process, so `cicerone` must be
# installed (not just loadable from the source tree) before these tests
# run -- see the header comment in helper-e2e.R.
library(shiny)
library(cicerone)

mod_ui <- function(id) {
  ns <- NS(id)
  tags$div(id = ns("inner"), "module content")
}

mod_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    invisible(NULL)
  })
}

guide <- Cicerone$
  new(id = "e2e")$
  step(
    el = "el1",
    title = "Step 1",
    description = "First element, first tab."
  )$
  step(
    el = "el2",
    title = "Step 2",
    description = "Second element, first tab."
  )$
  step(
    el = "in_tab2",
    title = "Step 3",
    description = "Element on the second tab.",
    tab = "Second",
    tab_id = "tabs"
  )

hints <- Hints$
  new(id = "e2e_hints")$
  hint(
    el = "el3",
    title = "Hint",
    description = "A hint on el3."
  )

# WP1: a step whose `on_close` declines the close (returns `false`), which
# must keep the tour open.
guide_close_false <- Cicerone$
  new(id = "e2e_close_false")$
  step(
    el = "el1",
    title = "Close-false step",
    on_close = "function(){ return false; }"
  )

# WP1 driver.js-parity: the last (only) step has `on_next` but no
# `on_done`; clicking the Done button must still fire the user's `on_next`
# hook and the tour must still end with reason "done" (the pre-2.1.0
# `onNextClick` fallback NAS relies on).
guide_parity <- Cicerone$
  new(id = "e2e_parity")$
  step(
    el = "el1",
    title = "Parity step",
    on_next = "function(){ Shiny.setInputValue('last_next_fired', true, {priority: 'event'}); }"
  )

# WP1 driver.js-parity: a config-level `on_close_click` that destroys the
# tour itself (the documented 2.0.0 pattern) must not throw on cicerone's
# own follow-up destroy(), and `_ended` must fire exactly once.
guide_close_destroy <- Cicerone$
  new(
    id = "e2e_close_destroy",
    on_close_click = "function(el, step, opts){ opts.driver.destroy(); }"
  )$
  step(el = "el1", title = "Close-destroy step")

# WP1: a hint whose `on_button_click` does nothing (no explicit dismiss)
# must still auto-dismiss, matching driver.js's default click behaviour.
hints_button <- Hints$
  new(id = "e2e_hints_button")$
  hint(
    el = "el1",
    title = "Button hint",
    on_button_click = "function(){}"
  )

ui <- fluidPage(
  use_cicerone(),
  tags$div(id = "el1", "Element 1"),
  tags$div(id = "el2", "Element 2"),
  tags$div(id = "el3", "Element 3"),
  tabsetPanel(
    id = "tabs",
    tabPanel("First", tags$div("first tab content")),
    tabPanel("Second", tags$div(id = "in_tab2", "In tab 2"))
  ),
  mod_ui("m"),
  actionButton("trigger", "Not a tour target"),
  actionButton("btn_start", "Start tour"),
  actionButton("btn_reset", "Reset tour"),
  actionButton("btn_move_to_2", "Move to step 2"),
  actionButton("btn_show_hints", "Show hints"),
  actionButton("btn_start_close_false", "Start close-false tour"),
  actionButton("btn_start_parity", "Start parity tour"),
  actionButton("btn_start_close_destroy", "Start close-destroy tour"),
  actionButton("btn_show_hints_button", "Show button hint"),
  verbatimTextOutput("out_state"),
  verbatimTextOutput("out_next"),
  verbatimTextOutput("out_previous"),
  verbatimTextOutput("out_reset"),
  verbatimTextOutput("out_reset_global"),
  verbatimTextOutput("out_hint_opened"),
  verbatimTextOutput("out_hint_dismissed"),
  verbatimTextOutput("out_hint_button")
)

server <- function(input, output, session) {
  mod_server("m")

  guide$init()
  hints$init()
  guide_close_false$init()
  guide_parity$init()
  guide_close_destroy$init()
  hints_button$init()

  observeEvent(input$btn_start, guide$start())
  observeEvent(input$btn_reset, guide$reset())
  observeEvent(input$btn_move_to_2, guide$move_to(2))
  observeEvent(input$btn_show_hints, hints$show())
  observeEvent(input$btn_start_close_false, guide_close_false$start())
  observeEvent(input$btn_start_parity, guide_parity$start())
  observeEvent(input$btn_start_close_destroy, guide_close_destroy$start())
  observeEvent(input$btn_show_hints_button, hints_button$show())

  output$out_state <- renderPrint(input[["e2e_cicerone_state"]])
  output$out_next <- renderPrint(input[["e2e_cicerone_next"]])
  output$out_previous <- renderPrint(input[["e2e_cicerone_previous"]])
  output$out_reset <- renderPrint(input[["e2e_cicerone_reset"]])
  output$out_reset_global <- renderPrint(input[["cicerone_reset"]])
  output$out_hint_opened <- renderPrint(input[["e2e_hints_cicerone_hint_opened"]])
  output$out_hint_dismissed <- renderPrint(input[["e2e_hints_cicerone_hint_dismissed"]])
  output$out_hint_button <- renderPrint(input[["e2e_hints_cicerone_hint_button"]])

  # WP1: accumulate the `e2e` tour's `_event` stream so the lifecycle e2e
  # test can assert the exact type sequence of a full run. Exported (not a
  # verbatimTextOutput) so the test can read it as plain data.
  event_log <- reactiveVal(character(0))
  observeEvent(input$e2e_cicerone_event, {
    event_log(c(event_log(), input$e2e_cicerone_event$type))
  })

  # WP1: count `_ended` fires for the close-destroy tour, to prove a user
  # `on_close_click` that destroys itself does not cause a double `_ended`.
  close_destroy_ended_count <- reactiveVal(0)
  observeEvent(input$e2e_close_destroy_cicerone_ended, {
    close_destroy_ended_count(close_destroy_ended_count() + 1)
  })

  session$exportTestValues(
    event_log = paste(event_log(), collapse = ","),
    close_destroy_ended_count = close_destroy_ended_count()
  )
}

shinyApp(ui, server)
