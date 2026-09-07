# WP5 end-to-end coverage: cookie persistence, the session$userData
# adapter backend, `run_once` suppression, `resume`, `$forget()`, and
# version mismatches, driven through a real browser via
# shinytest2/chromote. Skipped unless CICERONE_E2E=true (see
# helper-e2e.R for the install requirement this implies).
#
# Reload finding (see helper-e2e.R's `e2e_reload()` for the full
# explanation): a raw `app$run_js("location.reload()")` gets a fresh
# Shiny session, but breaks shinytest2's own instrumentation
# (`app$click()`/`app$wait_for_idle()`/`app$get_value()`/
# `app$wait_for_value()`/`exportTestValues()`). Every test below that
# reloads -- directly, or via `clear_cicerone_cookie()`, which reloads
# internally -- uses `e2e_reload()` (restores click/wait_for_idle) and
# reads values with `input_value_js()`/`wait_for_input_value_js()`/
# `persist_srv_record()` (avoid the now-stale HTTP session token)
# afterwards, for the rest of that test.
#
# Cross-instance cookie leak (confirmed empirically): shinytest2 runs
# every `e2e_app()` as a new tab in the SAME default Chromote browser
# instance/profile, and cookies are not port-scoped, so a `cicerone=`
# cookie written by one test is visible to the next one's `e2e_app()`
# too -- including at that fresh app's own initial page load, before a
# test gets a chance to run anything (`cicerone-init` already read and
# cached whatever cookie existed by then). `clear_cicerone_cookie()`
# clears the cookie AND reloads, which is what actually makes a clean
# slate take effect; every test that cares about the cookie's exact
# contents (or about `run_once`, which a leftover "completed" record
# would silently suppress) calls it first.

test_that("completing persist_cookie writes a completed record; a reload shows it via _seen and the server-rendered tour_state() output", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)
  clear_cicerone_cookie(app)

  app$click(input = "btn_start_persist_cookie")
  wait_for_input_value_js(app, "persist_cookie_cicerone_state")
  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_idle()
  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_idle()
  app$click(selector = ".driver-popover-next-btn") # Done (3rd/last step)
  wait_for_input_value_js(app, "persist_cookie_cicerone_ended")

  record <- cookie_record_js(app, "persist_cookie")
  expect_equal(record$status, "completed")
  expect_equal(record$idx, 2)

  e2e_reload(app)

  seen <- input_value_js(app, "persist_cookie_cicerone_seen")
  expect_equal(seen$status, "completed")

  # proves the synchronous server read: tour_state(session, "persist_cookie")
  # is rendered once, at session start, from session$request$HTTP_COOKIE
  # the output renders after the reload's new session connects; do not read
  # it before it has text (CI runners are slow enough to race this)
  app$wait_for_js(
    "(function(){ var el = document.querySelector('#out_persist_cookie_state_at_start'); return !!el && el.textContent.trim().length > 0; })()",
    timeout = 10000
  )
  server_state <- app$get_text("#out_persist_cookie_state_at_start")
  expect_match(server_state, "completed")
})

test_that("run_once = TRUE suppresses the next start when the persisted record is already completed", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)
  clear_cicerone_cookie(app)

  seed_cicerone_cookie(app, list(persist_cookie = list(
    v = 1, status = "completed", idx = 2, n = 1, t = "2026-01-01T00:00:00Z"
  )))
  e2e_reload(app)

  seen <- input_value_js(app, "persist_cookie_cicerone_seen")
  expect_equal(seen$status, "completed")

  app$click(input = "btn_start_persist_cookie")
  ended <- wait_for_input_value_js(app, "persist_cookie_cicerone_ended")
  expect_equal(ended$reason, "suppressed")
  expect_false(ended$completed)

  # a suppressed start must not touch the DOM at all
  expect_false(app$get_js("!!document.querySelector('.driver-popover')"))
})

test_that("$start(resume = TRUE) resumes at the persisted idx after a reload with no explicit dismiss", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)
  clear_cicerone_cookie(app)

  app$click(input = "btn_start_persist_cookie")
  wait_for_input_value_js(app, "persist_cookie_cicerone_state")
  app$click(selector = ".driver-popover-next-btn") # step 2, index 1
  app$wait_for_idle()

  # reload with NO close/reset: the tour is simply abandoned mid-step,
  # so the persisted record's status stays "in_progress" at idx 1 --
  # exactly what `resume` needs (an explicit dismiss writes "dismissed",
  # which `resume` deliberately ignores; see ?Cicerone's Persistence
  # section)
  before_reload <- cookie_record_js(app, "persist_cookie")
  expect_equal(before_reload$status, "in_progress")
  expect_equal(before_reload$idx, 1)

  e2e_reload(app)

  app$click(input = "btn_resume_persist_cookie")
  started <- wait_for_input_value_js(app, "persist_cookie_cicerone_started", timeout = 8000)
  expect_equal(started$index, 1)
})

test_that("$forget() removes the persisted record and clears _seen", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)
  clear_cicerone_cookie(app)

  app$click(input = "btn_start_persist_cookie")
  wait_for_input_value_js(app, "persist_cookie_cicerone_state")
  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_idle()
  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_idle()
  app$click(selector = ".driver-popover-next-btn")
  wait_for_input_value_js(app, "persist_cookie_cicerone_ended")
  expect_false(is.null(cookie_record_js(app, "persist_cookie")))

  app$click(input = "btn_forget_persist_cookie")
  app$wait_for_idle()

  expect_null(cookie_record_js(app, "persist_cookie"))
  expect_null(input_value_js(app, "persist_cookie_cicerone_seen"))
})

test_that("a version mismatch reads as no record while the raw cookie entry remains", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)
  clear_cicerone_cookie(app)

  # a v1 record for persist_cookie_v2's key, as if written by an
  # earlier release of the host app before it bumped `version` to 2
  seed_cicerone_cookie(app, list(persist_cookie_v2 = list(
    v = 1, status = "completed", idx = 0, n = 1, t = "2026-01-01T00:00:00Z"
  )))
  e2e_reload(app)

  seen <- input_value_js(app, "persist_cookie_v2_cicerone_seen")
  expect_null(seen)

  # tour_state()/the raw cookie are unfiltered by version -- the v1
  # entry is still there, untouched; the package does not migrate it
  raw <- cookie_record_js(app, "persist_cookie_v2")
  expect_equal(raw$v, 1)
  expect_equal(raw$status, "completed")
})

test_that("two persisted tours coexist as separate keys in the one cookie", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)
  clear_cicerone_cookie(app)

  app$click(input = "btn_start_persist_cookie")
  wait_for_input_value_js(app, "persist_cookie_cicerone_state")

  # exclusive = TRUE (the default) supersedes persist_cookie here, which
  # is fine for this test: it only asserts both KEYS are present, not
  # that both tours are simultaneously active
  app$click(input = "btn_start_persist_v2")
  wait_for_input_value_js(app, "persist_cookie_v2_cicerone_state")
  app$wait_for_idle()

  keys <- app$get_js(
    "Object.keys(JSON.parse(decodeURIComponent(document.cookie.match(/cicerone=([^;]*)/)[1])))"
  )
  expect_setequal(keys, c("persist_cookie", "persist_cookie_v2"))
})

test_that("adapter backend: completing writes to the session$userData store, _seen reflects it, and $forget() clears both", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_start_persist_srv")
  app$wait_for_value(input = "persist_srv_cicerone_state")
  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_idle()
  app$click(selector = ".driver-popover-next-btn") # Done (2nd/last step)
  app$wait_for_value(input = "persist_srv_cicerone_ended")
  wait_for_srv_record(app, "completed")

  record <- persist_srv_record(app)
  expect_equal(record$status, "completed")

  # re-init in the SAME session (no reload): re-reads the adapter
  # store, re-pushes the record via cicerone-persist-record, re-emits
  # _seen
  app$click(input = "btn_reinit_persist_srv")
  app$wait_for_idle()
  seen <- input_value(app, "persist_srv_cicerone_seen")
  expect_equal(seen$status, "completed")

  app$click(input = "btn_forget_persist_srv")
  app$wait_for_idle()
  wait_for_srv_record(app, NULL)

  expect_null(persist_srv_record(app))
  expect_null(input_value(app, "persist_srv_cicerone_seen"))
})

test_that("both backends produce the same record shape for the same event sequence", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)
  clear_cicerone_cookie(app)

  app$click(input = "btn_start_persist_cookie")
  wait_for_input_value_js(app, "persist_cookie_cicerone_started")
  app$wait_for_idle()
  cookie_record <- cookie_record_js(app, "persist_cookie")

  app$click(input = "btn_start_persist_srv")
  wait_for_input_value_js(app, "persist_srv_cicerone_started")
  app$wait_for_idle()
  wait_for_srv_record(app, "in_progress")
  adapter_record <- persist_srv_record(app)

  expect_equal(cookie_record$v, adapter_record$v)
  expect_equal(cookie_record$status, adapter_record$status)
  expect_equal(cookie_record$idx, adapter_record$idx)
  expect_equal(cookie_record$n, adapter_record$n)
  # `t` is compared only for ISO-8601 shape, not exact value: the two
  # records are written a moment apart, by two independent backends
  # (JS for the cookie, R for the adapter)
  iso_prefix <- "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}"
  expect_match(cookie_record$t, iso_prefix)
  expect_match(adapter_record$t, iso_prefix)
})

test_that("a tour with no persist leaves no cicerone cookie", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)
  clear_cicerone_cookie(app)

  app$click(input = "btn_start")
  wait_for_input_value_js(app, "e2e_cicerone_state")
  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_idle()
  app$click(input = "btn_reset")
  app$wait_for_idle()

  expect_false(grepl("cicerone=", app$get_js("document.cookie"), fixed = TRUE))
})
