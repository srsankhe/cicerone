# Small, deterministic fixture app for the shinytest2 end-to-end harness
# (WP0). Exercises the full Shiny <-> driver.js bridge: a 3-step tour that
# crosses a tabset and a module namespace, plus a one-hint Hints object.
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

  observeEvent(input$btn_start, guide$start())
  observeEvent(input$btn_reset, guide$reset())
  observeEvent(input$btn_move_to_2, guide$move_to(2))
  observeEvent(input$btn_show_hints, hints$show())

  output$out_state <- renderPrint(input[["e2e_cicerone_state"]])
  output$out_next <- renderPrint(input[["e2e_cicerone_next"]])
  output$out_previous <- renderPrint(input[["e2e_cicerone_previous"]])
  output$out_reset <- renderPrint(input[["e2e_cicerone_reset"]])
  output$out_reset_global <- renderPrint(input[["cicerone_reset"]])
  output$out_hint_opened <- renderPrint(input[["e2e_hints_cicerone_hint_opened"]])
  output$out_hint_dismissed <- renderPrint(input[["e2e_hints_cicerone_hint_dismissed"]])
  output$out_hint_button <- renderPrint(input[["e2e_hints_cicerone_hint_button"]])
}

shinyApp(ui, server)
