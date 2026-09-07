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
  )$
  step(
    el = "m-inner",
    title = "Step 4",
    description = "Element inside a Shiny module."
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

# Copilot review item B: a step-level `on_highlighted` override must not
# skip the config-level highlight bookkeeping (`_state`, `_started`, the
# `started`/`highlighted` events) -- only re-arm `advance_on`/`advance_when`.
guide_step_highlighted <- Cicerone$
  new(id = "e2e_step_highlighted")$
  step(
    el = "el1", title = "Step-level on_highlighted",
    on_highlighted = "function(){}"
  )

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

# WP9/Copilot review item F: a standalone highlight() call (no preceding
# initialise()/$init() for this id) with progress_style = "bar" -- the
# ad hoc driver.js instance highlight() creates on first use must still
# render the bar (see the wrapPopoverRender() call in tour.js's
# cicerone-highlight-man handler).
adhoc_highlight <- function() {
  highlight(
    "el1", "e2e_adhoc", title = "Ad hoc", progress_style = "bar"
  )
}
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

# `wait_for_visible` targeting #late_visible (hidden until
# #btn_reveal_late_visible is clicked, then shown 1s later -- see the UI
# fixture below): long enough to see it appear, and short enough to time
# out while it is still hidden.
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
    description = "wait_for_visible shorter than the 1s reveal.",
    wait_for_visible = 300
  )
# --- WP7 end ---
# --- async-safety begin: stale wait_for_visible completion fixtures ---
# A 2-step tour whose SECOND step targets #late_visible with a long
# enough `wait_for_visible` to still be pending when the tour is reset
# and immediately restarted mid-wait (see test-e2e-anchor.R's async
# safety tests): step 1 (el1) is always visible, so `$start()` itself
# never gates on anything -- only the Next-click gate (bridge.js's
# gateMove(), not cicerone-start's own wait) is exercised here.
guide_anchor_race <- Cicerone$
  new(id = "e2e_anchor_race")$
  step(el = "el1", title = "Race 1")$
  step(
    el = "late_visible", title = "Race 2",
    wait_for_visible = 2000
  )
# --- async-safety end ---
# --- WP4 begin: mutable tours / show_if fixtures ---

# `$set_steps()`/`$clear_steps()`/`$set_config()` and `show_if`. Step 2's
# `show_if` reads the `#show_step2` checkbox live, so toggling it between
# two `$start()`s (with an intervening `$reset()`) proves predicates are
# re-evaluated fresh each time, not cached from the first `$init()`.
guide_steps <- Cicerone$
  new(id = "e2e_steps")$
  step(el = "el1", title = "Steps 1", description = "First element.")$
  step(
    el = "el2", title = "Steps 2", description = "Second element.",
    show_if = "(step, opts) => document.querySelector('#show_step2').checked"
  )$
  step(el = "el3", title = "Steps 3", description = "Third element.")

# Copilot review item C: `$start(step = )` requesting a step that
# `show_if` removes, with nothing visible after it either -- the
# requested (last, index 2) step is always hidden, so the tour must fall
# back to the LAST VISIBLE step (index 1, "Tail 2"), not fire
# `no_visible_steps` (that only fires when the filtered list is empty).
guide_showif_tail <- Cicerone$
  new(id = "e2e_showif_tail")$
  step(el = "el1", title = "Tail 1")$
  step(el = "el2", title = "Tail 2")$
  step(el = "el3", title = "Tail 3 (always hidden)", show_if = "() => false")
# --- WP4 end ---
# Note: the persistence fixtures (persist_cookie, persist_cookie_v2,
# persist_srv) are NOT defined here at script scope, unlike every tour
# above. They are built fresh inside server() below -- see the WP5
# comment there for why: a `Cicerone` object created at script scope is
# shared by every session this R process ever serves (including a
# session that exists only because of a `location.reload()`), so its
# private `run_once`/`runs` counter would leak across sessions/reloads
# too, defeating the very reload-across-persistence scenarios this
# fixture exists to test.

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
  actionButton("btn_move_forward", "Move forward ($move_forward())"),
  actionButton("btn_show_hints", "Show hints"),
  actionButton("btn_start_close_false", "Start close-false tour"),
  actionButton("btn_start_parity", "Start parity tour"),
  actionButton("btn_start_close_destroy", "Start close-destroy tour"),
  actionButton("btn_start_step_highlighted", "Start step-highlighted-override tour"),
  actionButton("btn_show_hints_button", "Show button hint"),
  actionButton("btn_start_bar", "Start bar tour"),
  actionButton("btn_bar_set_config_text", "Set bar tour progress_style = text"),
  actionButton("btn_start_dots", "Start dots tour"),
  actionButton("btn_start_themed", "Start themed tour"),
  actionButton("btn_highlight_adhoc", "Highlight ad hoc (bar progress)"),
  actionButton("btn_forget_no_persist", "Forget tour with no persist"),
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
  # Copilot review item G: #late_visible used to reveal itself 1s after
  # PAGE LOAD unconditionally, which the anchor_ok/anchor_timeout tests
  # relied on staying hidden long enough after the *test*, not the page,
  # started -- flaky under a slow page load/click round trip. It now
  # stays hidden until #btn_reveal_late_visible is clicked, and reveals
  # itself 1s after THAT click instead, so every test controls its own
  # timing baseline.
  tags$div(id = "late_visible", style = "display:none;", "Late visible element"),
  actionButton("btn_reveal_late_visible", "Reveal #late_visible after 1s"),
  tags$script(HTML(
    "document.addEventListener('click', function(e){
       if (!e.target || e.target.id !== 'btn_reveal_late_visible') return;
       var el = document.getElementById('late_visible');
       if (!el) return;
       el.style.display = 'none';
       setTimeout(function(){ el.style.display = 'block'; }, 1000);
     });"
  )),
  actionButton("chain_trigger", "Chain trigger (WP7)"),
  actionButton("btn_start_b", "Start tour B"),
  actionButton("btn_start_nonexcl", "Start non-exclusive tour"),
  actionButton("btn_start_chain", "Start chain tour"),
  actionButton("btn_destroy_all", "Destroy all tours"),
  actionButton("btn_insert_late", "Insert #late after 1s"),
  actionButton("btn_start_anchor_ok", "Start anchor-ok tour"),
  actionButton("btn_reset_anchor_ok", "Reset anchor-ok tour"),
  actionButton("btn_start_anchor_timeout", "Start anchor-timeout tour"),
  actionButton("btn_wait_late", "wait_for_element(#late)"),
  actionButton("btn_wait_never", "wait_for_element(#never)"),
  actionButton("btn_wait_in_tab2", "wait_for_element(#in_tab2)"),
  # --- WP7 end ---
  # --- async-safety begin: stale wait_for_visible completion fixtures ---
  actionButton("btn_start_anchor_race", "Start anchor-race tour"),
  actionButton("btn_reset_anchor_race", "Reset anchor-race tour"),
  # --- async-safety end ---

  # --- WP4 begin: mutable tours / show_if fixtures ---
  checkboxInput("show_step2", "Show step 2", value = FALSE),
  actionButton("btn_start_steps", "Start steps tour"),
  actionButton("btn_reset_steps", "Reset steps tour"),
  actionButton("btn_rebuild_steps", "Rebuild to one step"),
  actionButton("btn_set_overlay_opacity", "Set overlay opacity 0.1"),
  actionButton("btn_start_showif_tail", "Start show_if-tail tour (requests hidden last step)"),
  # --- WP4 end ---
  # --- WP5 begin: persistence fixtures ---
  actionButton("btn_start_persist_cookie", "Start persist_cookie tour"),
  actionButton("btn_resume_persist_cookie", "Resume persist_cookie tour"),
  actionButton("btn_forget_persist_cookie", "Forget persist_cookie tour"),
  actionButton("btn_start_persist_v2", "Start persist_cookie_v2 tour"),
  actionButton("btn_start_persist_srv", "Start persist_srv tour"),
  actionButton("btn_reinit_persist_srv", "Re-init persist_srv tour"),
  actionButton("btn_forget_persist_srv", "Forget persist_srv tour"),
  # tour_state() evaluated once, synchronously, when the session's
  # server function runs -- proves the "read at server start" claim
  # (session$request$HTTP_COOKIE reflects whatever cookie the browser
  # sent on THIS page load/reconnect, before any Shiny input arrives)
  verbatimTextOutput("out_persist_cookie_state_at_start"),
  # JSON text (not renderPrint's list format) so a test can
  # jsonlite::fromJSON() it directly; read via app$get_text(), which is
  # JS/CDP-based and (unlike app$get_value()/exportTestValues()) still
  # works after an app$run_js("location.reload()") -- see helper-e2e.R.
  verbatimTextOutput("out_persist_srv_record")
  # --- WP5 end ---
)

server <- function(input, output, session) {
  mod_server("m")

  guide$init()
  hints$init()
  guide_close_false$init()
  guide_parity$init()
  guide_close_destroy$init()
  guide_step_highlighted$init()
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
  # --- async-safety begin ---
  guide_anchor_race$init()
  # --- async-safety end ---
  # --- WP4 begin: mutable tours / show_if init ---
  guide_steps$init()
  guide_showif_tail$init()
  # --- WP4 end ---
  # --- WP5 begin: persistence init ---
  # Built here, fresh per session, not at script scope like every other
  # tour above (see the comment left in their place): a script-scope
  # object's private run_once/runs counter is shared by every session
  # this R process serves, including a session that only exists because
  # of test-e2e-persist.R's own `location.reload()`.
  guide_persist_cookie <- Cicerone$
    new(id = "persist_cookie", persist = "cookie")$
    step(el = "el1", title = "Persist 1", description = "Step 1 of 3.")$
    step(el = "el2", title = "Persist 2", description = "Step 2 of 3.")$
    step(el = "el3", title = "Persist 3", description = "Step 3 of 3.")
  guide_persist_cookie$init(run_once = TRUE)

  # Same id *family* as persist_cookie (shares the "persist_cookie"
  # prefix for readability) but its own cookie key
  # ("persist_cookie_v2") and its own `version = 2`. Used two ways in
  # test-e2e-persist.R: (1) with a v1 record seeded directly via
  # `document.cookie` before this tour's own `$init()` ever runs, to
  # prove a version mismatch reads as no record while leaving the raw
  # cookie entry alone; (2) run fresh (no seeding), to prove two
  # persisted tours coexist as separate keys in the one cookie.
  guide_persist_v2 <- Cicerone$
    new(id = "persist_cookie_v2", persist = "cookie", version = 2)$
    step(el = "el1", title = "Persist v2", description = "Version-2 tour.")
  guide_persist_v2$init()

  # session$userData adapter: needs `session`, so the tour itself is
  # built here rather than at the top of the script (see ?Cicerone's
  # Persistence section for this same pattern). `session$userData`
  # mutations are not themselves reactive, so `persist_srv_record_ver`
  # is bumped from inside write()/forget() (synchronously, right after
  # the mutation, in the SAME call -- no observer-ordering ambiguity)
  # purely to give `out_persist_srv_record` below something reactive to
  # invalidate on.
  persist_srv_record_ver <- reactiveVal(0)
  persist_srv_adapter <- list(
    read = function(id) session$userData$cicerone_tours[[id]],
    write = function(id, record) {
      if (is.null(session$userData$cicerone_tours))
        session$userData$cicerone_tours <- list()
      session$userData$cicerone_tours[[id]] <- record
      persist_srv_record_ver(isolate(persist_srv_record_ver()) + 1)
    },
    forget = function(id) {
      session$userData$cicerone_tours[[id]] <- NULL
      persist_srv_record_ver(isolate(persist_srv_record_ver()) + 1)
    }
  )
  guide_persist_srv <- Cicerone$
    new(id = "persist_srv", persist = persist_srv_adapter)$
    step(el = "el1", title = "Persist srv 1", description = "Step 1 of 2.")$
    step(el = "el2", title = "Persist srv 2", description = "Step 2 of 2.")
  guide_persist_srv$init()
  # --- WP5 end ---

  observeEvent(input$btn_start, guide$start())
  observeEvent(input$btn_reset, guide$reset())
  observeEvent(input$btn_move_to_2, guide$move_to(2))
  observeEvent(input$btn_move_forward, guide$move_forward())
  observeEvent(input$btn_show_hints, hints$show())
  observeEvent(input$btn_start_close_false, guide_close_false$start())
  observeEvent(input$btn_start_parity, guide_parity$start())
  observeEvent(input$btn_start_close_destroy, guide_close_destroy$start())
  observeEvent(input$btn_start_step_highlighted, guide_step_highlighted$start())
  observeEvent(input$btn_show_hints_button, hints_button$show())
  observeEvent(input$btn_start_adv, guide_adv$start())
  observeEvent(input$btn_reset_adv, guide_adv$reset())
  observeEvent(input$btn_start_bar, guide_bar$start())
  observeEvent(input$btn_bar_set_config_text, {
    guide_bar$set_config(progress_style = "text")
  })
  observeEvent(input$btn_start_dots, guide_dots$start())
  observeEvent(input$btn_start_themed, guide_themed$start())
  observeEvent(input$btn_highlight_adhoc, adhoc_highlight())
  observeEvent(input$btn_forget_no_persist, guide$forget())
  # --- WP7 begin: exclusive / destroy_all / anchor observers ---
  observeEvent(input$btn_start_b, guide_b$start())
  observeEvent(input$btn_start_nonexcl, guide_nonexcl$start())
  observeEvent(input$btn_start_chain, guide_chain$start())
  observeEvent(input$btn_destroy_all, destroy_all())
  observeEvent(input$btn_start_anchor_ok, guide_anchor_ok$start())
  observeEvent(input$btn_reset_anchor_ok, guide_anchor_ok$reset())
  observeEvent(input$btn_start_anchor_timeout, guide_anchor_timeout$start())
  # --- async-safety begin ---
  observeEvent(input$btn_start_anchor_race, guide_anchor_race$start())
  observeEvent(input$btn_reset_anchor_race, guide_anchor_race$reset())
  # --- async-safety end ---

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
  # --- WP4 begin: mutable tours / show_if observers ---
  observeEvent(input$btn_start_steps, guide_steps$start())
  observeEvent(input$btn_reset_steps, guide_steps$reset())
  observeEvent(input$btn_rebuild_steps, {
    guide_steps$
      clear_steps()$
      step(el = "el1", title = "Rebuilt to one step")$
      set_steps()
  })
  observeEvent(input$btn_set_overlay_opacity, {
    guide_steps$set_config(overlay_opacity = 0.1)
  })
  observeEvent(input$btn_start_showif_tail, guide_showif_tail$start(step = 3))
  # --- WP4 end ---

  # --- WP5 begin: persistence observers ---
  observeEvent(input$btn_start_persist_cookie, guide_persist_cookie$start())
  observeEvent(input$btn_resume_persist_cookie, guide_persist_cookie$start(resume = TRUE))
  observeEvent(input$btn_forget_persist_cookie, guide_persist_cookie$forget())
  observeEvent(input$btn_start_persist_v2, guide_persist_v2$start())
  observeEvent(input$btn_start_persist_srv, guide_persist_srv$start())
  observeEvent(input$btn_reinit_persist_srv, guide_persist_srv$init())
  observeEvent(input$btn_forget_persist_srv, guide_persist_srv$forget())
  # --- WP5 end ---

  output$out_state <- renderPrint(input[["e2e_cicerone_state"]])
  output$out_next <- renderPrint(input[["e2e_cicerone_next"]])
  output$out_previous <- renderPrint(input[["e2e_cicerone_previous"]])
  output$out_reset <- renderPrint(input[["e2e_cicerone_reset"]])
  output$out_reset_global <- renderPrint(input[["cicerone_reset"]])
  output$out_hint_opened <- renderPrint(input[["e2e_hints_cicerone_hint_opened"]])
  output$out_hint_dismissed <- renderPrint(input[["e2e_hints_cicerone_hint_dismissed"]])
  output$out_hint_button <- renderPrint(input[["e2e_hints_cicerone_hint_button"]])
  # --- WP5 begin: server-start synchronous cookie read ---
  output$out_persist_cookie_state_at_start <- renderPrint(tour_state(session, "persist_cookie"))
  output$out_persist_srv_record <- renderText({
    persist_srv_record_ver()
    rec <- session$userData$cicerone_tours[["persist_srv"]]
    if (is.null(rec)) "null" else as.character(jsonlite::toJSON(rec, auto_unbox = TRUE))
  })
  # --- WP5 end ---

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
