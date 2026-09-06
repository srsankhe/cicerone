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
# --- WP7 begin: htmltools for the anchor fixture's inline <script> ---
library(htmltools)
# --- WP7 end ---

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

# WP6: a step advances on a named event on any element (not just the
# highlighted one), and a step advances when a JavaScript predicate turns
# true, re-evaluated as the page changes.
guide_adv <- Cicerone$
  new(id = "e2e_adv")$
  step(
    el = "el1",
    title = "Advance-on step",
    advance_on = "#trigger"
  )$
  step(
    el = "el2",
    title = "Plain step"
  )$
  step(
    el = "el3",
    title = "Advance-when step",
    advance_when = paste0(
      "() => document.querySelector('#adv_name').value.length > 0 && ",
      "document.querySelector('#adv_parsed').checked"
    )
  )
# WP9: progress variants (`progress_style`) and theming (`cicerone_theme()`).
guide_bar <- Cicerone$
  new(id = "e2e_bar", progress_style = "bar")$
  step(el = "el1", title = "Bar 1", description = "Step 1 of 3.")$
  step(el = "el2", title = "Bar 2", description = "Step 2 of 3.")$
  step(el = "el3", title = "Bar 3", description = "Step 3 of 3.")

guide_dots <- Cicerone$
  new(id = "e2e_dots", progress_style = "dots")$
  step(el = "el1", title = "Dots 1", description = "Step 1 of 3.")$
  step(el = "el2", title = "Dots 2", description = "Step 2 of 3.")$
  step(el = "el3", title = "Dots 3", description = "Step 3 of 3.")

guide_themed <- Cicerone$
  new(id = "e2e_themed", popover_class = "e2e-themed")$
  step(el = "el1", title = "Themed", description = "Accent should be red.")
# --- WP7 begin: exclusive / destroy_all / anchor fixtures ---

# A second, independent tour: exclusive start of this one (default) must
# supersede whatever else is active.
guide_b <- Cicerone$
  new(id = "e2e_b")$
  step(el = "el1", title = "B step 1", description = "Tour B, first element.")$
  step(el = "el2", title = "B step 2", description = "Tour B, second element.")

# `exclusive = FALSE`: starting this one must NOT destroy an active tour.
guide_nonexcl <- Cicerone$
  new(id = "e2e_nonexcl", exclusive = FALSE)$
  step(el = "el1", title = "Non-exclusive step")

# NAS-shape reproduction: this tour's last step highlights #chain_trigger; the
# `input$chain_trigger` observer below (modelling WP6's not-yet-available
# `advance_on`) starts tour B from there, superseding this one.
guide_chain <- Cicerone$
  new(id = "e2e_chain")$
  step(el = "el1", title = "Chain step 1")$
  step(el = "chain_trigger", title = "Chain step 2 (click me)")

# `wait_for_visible` targeting #late_visible (shown 1s after page load, see
# the UI fixture below): long enough to see it appear, and short enough to
# time out while it is still hidden.
guide_anchor_ok <- Cicerone$
  new(id = "e2e_anchor_ok")$
  step(
    el = "late_visible", title = "Anchor ok",
    description = "wait_for_visible long enough to see #late_visible appear.",
    wait_for_visible = 3000
  )

guide_anchor_timeout <- Cicerone$
  new(id = "e2e_anchor_timeout")$
  step(
    el = "late_visible", title = "Anchor timeout",
    description = "wait_for_visible shorter than the 1s hide.",
    wait_for_visible = 300
  )
# --- WP7 end ---

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
  actionButton("btn_start_bar", "Start bar tour"),
  actionButton("btn_start_dots", "Start dots tour"),
  actionButton("btn_start_themed", "Start themed tour"),
  verbatimTextOutput("out_state"),
  verbatimTextOutput("out_next"),
  verbatimTextOutput("out_previous"),
  verbatimTextOutput("out_reset"),
  verbatimTextOutput("out_reset_global"),
  verbatimTextOutput("out_hint_opened"),
  verbatimTextOutput("out_hint_dismissed"),
  verbatimTextOutput("out_hint_button"),
  textInput("adv_name", "Name", value = ""),
  checkboxInput("adv_parsed", "Parsed", value = FALSE),
  actionButton("btn_start_adv", "Start advance tour"),
  actionButton("btn_reset_adv", "Reset advance tour"),
  cicerone_theme(accent = "#ff0000", selector = ".e2e-themed"),

  # --- WP7 begin: exclusive / destroy_all / anchor fixtures ---
  tags$div(id = "late_visible", style = "display:none;", "Late visible element"),
  tags$script(HTML(
    "setTimeout(function(){
       var el = document.getElementById('late_visible');
       if (el) el.style.display = 'block';
     }, 1000);"
  )),
  actionButton("chain_trigger", "Chain trigger (WP7)"),
  actionButton("btn_start_b", "Start tour B"),
  actionButton("btn_start_nonexcl", "Start non-exclusive tour"),
  actionButton("btn_start_chain", "Start chain tour"),
  actionButton("btn_destroy_all", "Destroy all tours"),
  actionButton("btn_insert_late", "Insert #late after 1s"),
  actionButton("btn_start_anchor_ok", "Start anchor-ok tour"),
  actionButton("btn_start_anchor_timeout", "Start anchor-timeout tour"),
  actionButton("btn_wait_late", "wait_for_element(#late)"),
  actionButton("btn_wait_never", "wait_for_element(#never)"),
  actionButton("btn_wait_in_tab2", "wait_for_element(#in_tab2)")
  # --- WP7 end ---
)

server <- function(input, output, session) {
  mod_server("m")

  guide$init()
  hints$init()
  guide_close_false$init()
  guide_parity$init()
  guide_close_destroy$init()
  hints_button$init()
  guide_adv$init()
  guide_bar$init()
  guide_dots$init()
  guide_themed$init()
  # --- WP7 begin: exclusive / destroy_all / anchor init ---
  guide_b$init()
  guide_nonexcl$init()
  guide_chain$init()
  guide_anchor_ok$init()
  guide_anchor_timeout$init()
  # --- WP7 end ---

  observeEvent(input$btn_start, guide$start())
  observeEvent(input$btn_reset, guide$reset())
  observeEvent(input$btn_move_to_2, guide$move_to(2))
  observeEvent(input$btn_show_hints, hints$show())
  observeEvent(input$btn_start_close_false, guide_close_false$start())
  observeEvent(input$btn_start_parity, guide_parity$start())
  observeEvent(input$btn_start_close_destroy, guide_close_destroy$start())
  observeEvent(input$btn_show_hints_button, hints_button$show())
  observeEvent(input$btn_start_adv, guide_adv$start())
  observeEvent(input$btn_reset_adv, guide_adv$reset())
  observeEvent(input$btn_start_bar, guide_bar$start())
  observeEvent(input$btn_start_dots, guide_dots$start())
  observeEvent(input$btn_start_themed, guide_themed$start())
  # --- WP7 begin: exclusive / destroy_all / anchor observers ---
  observeEvent(input$btn_start_b, guide_b$start())
  observeEvent(input$btn_start_nonexcl, guide_nonexcl$start())
  observeEvent(input$btn_start_chain, guide_chain$start())
  observeEvent(input$btn_destroy_all, destroy_all())
  observeEvent(input$btn_start_anchor_ok, guide_anchor_ok$start())
  observeEvent(input$btn_start_anchor_timeout, guide_anchor_timeout$start())

  # NAS-shape reproduction: clicking the element e2e_chain's last step
  # highlights (#chain_trigger) starts tour B, modelling WP6's not-yet-available
  # `advance_on` with a plain observer instead.
  observeEvent(input$chain_trigger, guide_b$start())

  observeEvent(input$btn_insert_late, {
    later::later(function() {
      insertUI(
        selector = "body", where = "beforeEnd",
        ui = tags$div(id = "late", "Late element"),
        immediate = TRUE, session = session
      )
    }, delay = 1)
  })

  observeEvent(input$btn_wait_late, {
    wait_for_element("#late", timeout = 3000, id = "late")
  })
  observeEvent(input$btn_wait_never, {
    wait_for_element("#never", timeout = 500, id = "never")
  })
  observeEvent(input$btn_wait_in_tab2, {
    wait_for_element("#in_tab2", timeout = 500, id = "in_tab2")
  })
  # --- WP7 end ---

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

  # WP6: accumulate the `e2e_adv` tour's `_event` stream (type and element)
  # server-side. A live-value poll (as `app$wait_for_value()` does) can
  # only ever observe the latest value of an input, and `advance_on`
  # deliberately emits `event:"advance"` immediately before a `moveNext()`
  # that itself emits `event:"highlighted"` a frame later -- a client-side
  # poll can race straight past the first value. Exported (not a
  # verbatimTextOutput) so the test can read the exact sequence.
  adv_event_log <- reactiveVal(character(0))
  observeEvent(input$e2e_adv_cicerone_event, {
    ev <- input$e2e_adv_cicerone_event
    entry <- paste0(ev$type, ":", if (is.null(ev$element)) "" else ev$element)
    adv_event_log(c(adv_event_log(), entry))
  })

  # --- WP7 begin: event logs for the chain/anchor reproductions ---
  # `event_log`-style accumulators, scoped per tour, so a test can assert
  # e.g. "no start_failed/anchor_timeout ever fired", not just the latest
  # `_event`.
  chain_event_log <- reactiveVal(character(0))
  observeEvent(input$e2e_chain_cicerone_event, {
    chain_event_log(c(chain_event_log(), input$e2e_chain_cicerone_event$type))
  })

  b_event_log <- reactiveVal(character(0))
  observeEvent(input$e2e_b_cicerone_event, {
    b_event_log(c(b_event_log(), input$e2e_b_cicerone_event$type))
  })

  anchor_ok_event_log <- reactiveVal(character(0))
  observeEvent(input$e2e_anchor_ok_cicerone_event, {
    anchor_ok_event_log(c(anchor_ok_event_log(), input$e2e_anchor_ok_cicerone_event$type))
  })

  anchor_timeout_event_log <- reactiveVal(character(0))
  observeEvent(input$e2e_anchor_timeout_cicerone_event, {
    anchor_timeout_event_log(
      c(anchor_timeout_event_log(), input$e2e_anchor_timeout_cicerone_event$type)
    )
  })
  # --- WP7 end ---

  session$exportTestValues(
    event_log = paste(event_log(), collapse = ","),
    close_destroy_ended_count = close_destroy_ended_count(),
    adv_event_log = paste(adv_event_log(), collapse = ","),
    # --- WP7 begin ---
    chain_event_log = paste(chain_event_log(), collapse = ","),
    b_event_log = paste(b_event_log(), collapse = ","),
    anchor_ok_event_log = paste(anchor_ok_event_log(), collapse = ","),
    anchor_timeout_event_log = paste(anchor_timeout_event_log(), collapse = ",")
    # --- WP7 end ---
  )
}

shinyApp(ui, server)
