# Demo app for cicerone 2.0.0 (driver.js 1.x)
# Run with: shiny::runApp(system.file("examples/demo", package = "cicerone"))
library(shiny)
library(cicerone)

guide <- Cicerone$
  new(
    id = "demo-guide",
    show_progress = TRUE,
    progress_text = "{{current}} of {{total}}",
    overlay_opacity = .6,
    stage_radius = 8,
    smooth_scroll = TRUE
  )$
  step(
    title = "Welcome!",
    description = "This is an element-less, modal-like step. Click next to begin."
  )$
  step(
    el = "text",
    title = "Text Input",
    description = "This is where you enter the text you want to print.",
    side = "bottom",
    align = "start"
  )$
  step(
    "submit",
    "Send the Text",
    "Send the text to the server for printing.",
    advance_on_click = TRUE
  )$
  step(
    "print",
    "Printed Text",
    "The text you sent is printed here.",
    side = "top"
  )

hints <- Hints$
  new(id = "demo-hints", button_text = "Got it")$
  hint(
    el = "restart",
    title = "Restart the tour",
    description = "Click this button to run the guide again.",
    hint_id = "restart-hint"
  )

ui <- fluidPage(
  use_cicerone(),
  titlePanel("cicerone + driver.js 1.x demo"),
  textInput("text", "Enter some text"),
  actionButton("submit", "Submit text"),
  verbatimTextOutput("print"),
  hr(),
  actionButton("restart", "Restart tour"),
  actionButton("show_hints", "Show hints"),
  verbatimTextOutput("state")
)

server <- function(input, output, session){

  guide$init()$start()
  hints$init()

  observeEvent(input$restart, {
    guide$start()
  })

  observeEvent(input$show_hints, {
    hints$show()
  })

  # richer state, updated on every highlighted step
  output$state <- renderPrint({
    state <- guide$get_state()
    req(state)
    state
  })

  # tour ended
  observeEvent(input[["demo-guide_cicerone_reset"]], {
    showNotification("Tour ended!", type = "message")
  })

  txt <- eventReactive(input$submit, input$text)
  output$print <- renderPrint(txt())
}

shinyApp(ui, server)
