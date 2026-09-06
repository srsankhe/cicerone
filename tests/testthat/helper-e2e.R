# End-to-end test helpers (shinytest2 + chromote).
#
# shinytest2 launches the fixture app (tests/testthat/apps/e2e/app.R) in a
# separate, freshly-started R process. That process does `library(cicerone)`
# against whatever is on the library search path for that process -- it does
# NOT pick up the in-development sources of this package the way
# `testthat::test_local()` does for the rest of the suite. Before running
# these tests (locally or in CI), install the current worktree so the
# fixture app's `library(cicerone)` sees the code under test:
#
#   Rscript -e 'install.packages(".", repos = NULL, type = "source")'
#
# Tests are skipped unless CICERONE_E2E=true, so this requirement never
# affects `R CMD check`, CRAN, or a plain `testthat::test_local()` run.

skip_e2e <- function() {
  testthat::skip_if_not(
    Sys.getenv("CICERONE_E2E") == "true",
    "set CICERONE_E2E=true to run end-to-end (shinytest2) tests"
  )
  testthat::skip_if_not_installed("shinytest2")
}

e2e_app <- function() {
  shinytest2::AppDriver$new(
    testthat::test_path("apps/e2e"),
    load_timeout = 20000,
    variant = NULL
  )
}

# Read a Shiny input's live value from the running app (client-side, via
# shinytest2's JS bridge) without needing a verbatimTextOutput for it.
input_value <- function(app, name) {
  app$get_value(input = name)
}

# --- WP5 begin: reload support --------------------------------------------
#
# shinytest2's own instrumentation -- `window.shinytest2`, which backs
# `app$click()`/`app$set_inputs()`/`app$wait_for_idle()` (their input
# delivery and busy/idle tracking) -- and the session token baked into
# `app$get_value()`/`app$wait_for_value()`'s HTTP snapshot endpoint are
# both captured/injected exactly ONCE, right after the driver's original
# navigation (see `shinytest2:::app_initialize_()`, which navigates, then
# injects `inst/internal/js/shiny-tracer.js`, then reads
# `Shiny.shinyapp.getTestSnapshotBaseUrl()`). A raw
# `app$run_js("location.reload()")` gets a fresh Shiny session (a fresh
# `server()` call, a fresh `session$request`), but neither of those two
# things comes back on its own:
#   - `app$click(input =)`/`app$set_inputs()` silently no-op (the input is
#     queued against a `window.shinytest2` that no longer exists, and
#     never flushed) -- confirmed empirically, no error is raised.
#   - `app$get_value()`/`app$wait_for_value()` 404 (the session token in
#     the URL they call is the pre-reload session's, now dead).
#   - `app$wait_for_idle()` throws ("An error occurred while waiting for
#     Shiny to be stable"): its injected polling script itself calls
#     `window.shinytest2.log(...)`.
#
# `e2e_reload()` re-runs the same tracer-injection step
# `app_initialize_()` does, which fixes `click()`/`set_inputs()`/
# `wait_for_idle()`. It does NOT refresh the stale session token
# `get_value()`/`wait_for_value()` need (that lives in a private R6
# field with no public setter); use `input_value_js()`/
# `wait_for_input_value_js()` instead for anything read after a reload
# (they work equally well before one).
e2e_reload <- function(app, timeout = 15000) {
  app$run_js("location.reload()")
  app$wait_for_js(
    "document.readyState === 'complete' && !!window.Shiny",
    timeout = timeout
  )

  js_file <- system.file("internal", "js", "shiny-tracer.js", package = "shinytest2")
  js_content <- paste(readLines(js_file, warn = FALSE), collapse = "\n")
  invisible(utils::capture.output(
    app$get_chromote_session()$Runtime$evaluate(js_content)
  ))
  app$wait_for_js(
    "window.shinytest2 && window.shinytest2.ready === true",
    timeout = timeout
  )
  app$wait_for_idle(duration = 200, timeout = timeout)

  invisible(app)
}

# Read a Shiny input's current value from the browser's own client-side
# cache (`Shiny.shinyapp.$inputValues`), bypassing `app$get_value()`'s
# HTTP snapshot endpoint entirely. Safe to use before OR after
# `e2e_reload()`.
input_value_js <- function(app, name) {
  app$get_js(sprintf(
    "Shiny.shinyapp.$inputValues[%s]",
    jsonlite::toJSON(name, auto_unbox = TRUE)
  ))
}

# Poll `input_value_js()` until `predicate` is satisfied or `timeout` ms
# elapse. `app$wait_for_value()` has the same post-`e2e_reload()`
# limitation as `app$get_value()` (see above), so use this instead for
# anything that needs to wait after a reload.
wait_for_input_value_js <- function(app, name, predicate = Negate(is.null),
  timeout = 5000, interval = 100) {

  deadline <- Sys.time() + timeout / 1000
  repeat {
    value <- input_value_js(app, name)
    if (isTRUE(predicate(value))) return(invisible(value))
    if (Sys.time() > deadline) {
      testthat::fail(paste0(
        "wait_for_input_value_js(): timed out waiting for '", name, "'"
      ))
    }
    Sys.sleep(interval / 1000)
  }
}

# Set the `cicerone` cookie's raw value directly, bypassing the package
# entirely -- simulates a record written by an earlier session/app
# version. `map` is a named list of tour id -> record.
seed_cicerone_cookie <- function(app, map) {
  json <- as.character(jsonlite::toJSON(map, auto_unbox = TRUE))
  app$run_js(sprintf(
    "document.cookie = 'cicerone=' + encodeURIComponent(%s) + '; path=/'",
    jsonlite::toJSON(json, auto_unbox = TRUE)
  ))
  invisible(app)
}

# Clear the `cicerone` cookie, then reload. shinytest2 launches every
# `e2e_app()`'s Chrome tab as a new target in the SAME default
# Chromote browser instance/profile
# (`chromote::default_chromote_object()$new_session()` in
# `shinytest2:::app_initialize_()`), and cookies are not port-scoped, so
# a `cicerone=` cookie written by one `e2e_app()` instance is visible to
# every other one in the same test run (confirmed empirically) --
# including at THIS app's own initial page load, before a test gets a
# chance to run anything: `cicerone-init` (and, for `run_once = TRUE`,
# suppression) has already read whatever cookie existed at that point
# and cached it in `persist.js`'s in-memory registries. Clearing
# `document.cookie` after the fact does not retroactively un-cache
# that (confirmed empirically: a leftover "completed" record silently
# suppressed the very first `$start()` of an otherwise-unrelated test).
# The reload is what actually makes the fresh state take effect. Call
# this at the start of any test that must not be affected by a leftover
# cookie from an earlier one.
clear_cicerone_cookie <- function(app) {
  app$run_js("document.cookie = 'cicerone=; path=/; max-age=0'")
  e2e_reload(app)
  invisible(app)
}

# Read one tour's raw record straight out of `document.cookie`, parsed
# client-side (not through `tour_state()`/R at all) -- for asserting on
# exactly what persist.js wrote, independent of anything server-side.
# `NULL` if there is no `cicerone` cookie or no entry for `id`.
# Parse the persist_srv adapter store's record from its JSON
# `verbatimTextOutput` (see app.R's `out_persist_srv_record`), read via
# `app$get_text()` -- JS/CDP-based, so (unlike `app$get_value(export =
# )`, which needs a session token `e2e_reload()`/`clear_cicerone_cookie()`
# invalidate) it works both before and after a reload. `NULL` when the
# adapter has no record for persist_srv yet (or after `$forget()`).
# Wait until the fixture's rendered adapter record shows `status` (or, with
# status = NULL, until it is empty/"null"). The `_ended` input reaching the
# browser does not mean the server-side adapter write and the output
# re-render have happened yet; on a slow CI runner reading the DOM right
# after `wait_for_value(input = "..._ended")` races that render.
wait_for_srv_record <- function(app, status, timeout = 10000) {
  want <- if (is.null(status)) "null" else status
  app$wait_for_js(sprintf(
    "(function(){
       var el = document.querySelector('#out_persist_srv_record');
       if (!el) return false;
       var t = el.textContent.trim();
       if (!t || t === 'null') return %s;
       try {
         var r = JSON.parse(t);
         var s = Array.isArray(r.status) ? r.status[0] : r.status;
         return s === '%s';
       } catch (e) { return false; }
     })()",
    if (is.null(status)) "true" else "false", want
  ), timeout = timeout)
}

persist_srv_record <- function(app) {
  txt <- trimws(app$get_text("#out_persist_srv_record"))
  if (!nzchar(txt) || identical(txt, "null")) return(NULL)
  jsonlite::fromJSON(txt, simplifyVector = FALSE)
}

cookie_record_js <- function(app, id) {
  app$get_js(sprintf(
    "(function(){
       var m = document.cookie.match(/cicerone=([^;]*)/);
       if (!m) return null;
       var map = JSON.parse(decodeURIComponent(m[1]));
       return map[%s] || null;
     })()",
    jsonlite::toJSON(id, auto_unbox = TRUE)
  ))
}
# --- WP5 end -----------------------------------------------------------
