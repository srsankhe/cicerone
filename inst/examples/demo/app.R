# Showcase app for cicerone 2.1.0 (driver.js 1.8.0).
# Run with: shiny::runApp("inst/examples/demo")
#
# This app is the README's source of truth: every code block under
# "# README:" below is lifted verbatim into README.md, not retyped, so
# keep them copy-paste runnable on their own.
library(shiny)
library(bslib)
library(cicerone)

# README: Quick start --------------------------------------------------------
# An id, a few step()s, init() once, start() on demand.
# - progress_style = "bar" swaps the "n of m" text for a filled bar.
# - tab/tab_id switch a bslib navset_card_tab before highlighting a step's
#   element on another tab (confirmed: bslib's client-side BS3->BS5 nav
#   markup is what Shiny's own tab input binding expects, so this works
#   with no bslib-specific code).
# - advance_on moves on typing, not a Next click.
# - show_if re-checks a checkbox on every $start() to skip/keep a step.
# - persist = "cookie" remembers tour progress across page reloads.
tour <- Cicerone$
  new(
    id = "demo", progress_style = "bar", persist = "cookie",
    overlay_opacity = .6, stage_radius = 8, smooth_scroll = TRUE
  )$
  step(
    el = "name", title = "Say hello",
    description = "Type your name to get started.",
    advance_on = list(el = "#name", event = "input")
  )$
  step(
    el = "tab2_panel", title = "A second tab",
    description = "Here's what's on the Advanced tab.",
    tab = "Advanced", tab_id = "tabs"
  )$
  step(
    el = "btn_hints", title = "Optional step",
    description = "Only part of the tour while \"Reveal step 3\" is checked.",
    show_if = "(step, opts) => document.querySelector('#show_step3').checked"
  )

# README: Hints ---------------------------------------------------------
# Pulsing beacons; clicking one opens its popover, the button dismisses it.
hints <- Hints$
  new(id = "demo_hints", button_text = "Got it")$
  hint(el = "name", title = "Beacon 1", description = "A hint on the name field.")$
  hint(
    el = "show_step3", title = "Beacon 2",
    description = "Toggle this to add/remove step 3 of the tour."
  )

ui <- page_sidebar(
  title = "cicerone 2.1.0 demo",
  use_cicerone(),
  # README: Progress and theming ---------------------------------------------
  # cicerone_theme(preset = "bootstrap") maps popover colors to the app's
  # own bslib theme -- including dark mode -- via --bs-* CSS variables.
  uiOutput("popover_theme"),
  # `btn_hints` sits above the first hr() (rather than near the bottom, as
  # originally laid out) so its target is on screen at the recorder's
  # shorter GIF viewport without scrolling -- see media-ux-review.md item 1.
  sidebar = sidebar(
    input_dark_mode(id = "mode", mode = "light"),
    checkboxInput("theme_bootstrap", "Bootstrap-themed popovers"),
    actionButton("btn_hints", "Show hints"),
    hr(),
    actionButton("btn_start", "Start tour", class = "btn-primary"),
    actionButton("btn_forget", "Forget tour progress"),
    hr(),
    checkboxInput("show_step3", "Reveal step 3", value = TRUE),
    hr(),
    tags$strong("Last _ended payload"),
    verbatimTextOutput("ended")
  ),
  navset_card_tab(
    id = "tabs",
    nav_panel("Basics", textInput("name", "Your name", placeholder = "Type here")),
    nav_panel("Advanced", tags$div(id = "tab2_panel", "Content on the second tab."))
  )
)

server <- function(input, output, session) {
  tour$init()
  hints$init()

  observeEvent(input$btn_start, tour$start())
  observeEvent(input$btn_forget, tour$forget())
  observeEvent(input$btn_hints, hints$show())

  output$popover_theme <- renderUI({
    if (isTRUE(input$theme_bootstrap)) cicerone_theme(preset = "bootstrap")
  })

  # README: Lifecycle inputs --------------------------------------------------
  # {id}_cicerone_ended fires whenever the tour stops, with the reason
  # ("done", "close", "programmatic", "superseded", "suppressed", "dismissed").
  output$ended <- renderPrint({
    req(input$demo_cicerone_ended)
  })
}

shinyApp(ui, server)
