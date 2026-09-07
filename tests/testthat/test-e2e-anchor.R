# WP7 end-to-end coverage: `wait_for_element()` (standalone) and
# `wait_for_visible` (tour/step level). Driven through a real browser via
# shinytest2/chromote. Skipped unless CICERONE_E2E=true (see helper-e2e.R
# for the install requirement this implies).

test_that("wait_for_element resolves once a late-inserted element appears", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  # start polling before scheduling the insert, so the measured `elapsed`
  # reflects the insertUI delay (~1s), not click round-trip overhead
  app$click(input = "btn_wait_late")
  app$click(input = "btn_insert_late")
  app$wait_for_value(input = "late_cicerone_anchor", timeout = 5000)

  res <- input_value(app, "late_cicerone_anchor")
  expect_true(res$found)
  expect_gt(res$elapsed, 900)
  expect_lt(res$elapsed, 2500)
})

test_that("wait_for_element reports found = FALSE after timing out", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_wait_never")
  app$wait_for_value(input = "never_cicerone_anchor", timeout = 3000)

  res <- input_value(app, "never_cicerone_anchor")
  expect_false(res$found)
  expect_false(res$visible)
  expect_gt(res$elapsed, 400)
})

test_that("wait_for_element(visible = TRUE) reports found but not visible for a hidden tab", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  app$click(input = "btn_wait_in_tab2")
  app$wait_for_value(input = "in_tab2_cicerone_anchor", timeout = 3000)

  res <- input_value(app, "in_tab2_cicerone_anchor")
  expect_true(res$found)
  expect_false(res$visible)
})

test_that("wait_for_visible waits for a hidden step element to appear before highlighting it", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  # Copilot review item G: #late_visible no longer reveals itself off a
  # page-load timer (flaky under a slow load/click round trip) -- this
  # button (re)hides it, then reveals it 1s later, so the test controls
  # its own timing baseline.
  app$click(input = "btn_reveal_late_visible")
  app$click(input = "btn_start_anchor_ok")
  app$wait_for_value(input = "e2e_anchor_ok_cicerone_state", timeout = 5000)

  state <- input_value(app, "e2e_anchor_ok_cicerone_state")
  expect_equal(state$highlighted, "late_visible")

  app$wait_for_idle()

  # the popover is anchored on (near) the now-visible element, not
  # rendered somewhere unrelated on the page; a generous margin absorbs
  # driver.js's own stagePadding/popoverOffset gap between the two rects
  positioned_on_element <- app$get_js(
    "(function(){
      var popover = document.querySelector('.driver-popover');
      var el = document.getElementById('late_visible');
      if (!popover || !el) return false;
      var p = popover.getBoundingClientRect();
      var e = el.getBoundingClientRect();
      var margin = 50;
      return !(
        p.right + margin < e.left || p.left - margin > e.right ||
        p.bottom + margin < e.top || p.top - margin > e.bottom
      );
    })()"
  )
  expect_true(positioned_on_element)

  log <- strsplit(app$get_value(export = "anchor_ok_event_log"), ",")[[1]]
  expect_false("anchor_timeout" %in% log)
})

test_that("wait_for_visible timing out emits anchor_timeout and still moves", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  # #late_visible stays hidden the whole time here: the timeout (300ms)
  # is well short of the 1s reveal, so this test does not even need to
  # click #btn_reveal_late_visible -- but click it anyway, immediately
  # before starting, so this test does not depend on #late_visible's
  # state left over from an earlier test in the same app instance.
  app$click(input = "btn_reveal_late_visible")
  app$click(input = "btn_start_anchor_timeout")
  app$wait_for_value(input = "e2e_anchor_timeout_cicerone_state", timeout = 5000)

  state <- input_value(app, "e2e_anchor_timeout_cicerone_state")
  expect_equal(state$highlighted, "late_visible")

  app$wait_for_idle()
  log <- strsplit(app$get_value(export = "anchor_timeout_event_log"), ",")[[1]]
  expect_true("anchor_timeout" %in% log)
})

test_that("a start-time wait_for_visible timeout honours skip_missing_element (Copilot review item 4)", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  # #late_visible is never revealed in this test (btn_reveal_late_visible
  # is never clicked), so the 300ms wait on step 1 always times out;
  # skip_missing_element = TRUE must then land the start on step 2 (#el2)
  # instead of driving step 1 anyway.
  app$click(input = "btn_start_skip_start")
  app$wait_for_value(input = "e2e_skip_start_cicerone_state", timeout = 5000)

  state <- input_value(app, "e2e_skip_start_cicerone_state")
  expect_equal(state$index, 1)
  expect_equal(state$highlighted, "el2")

  app$wait_for_idle()
  log <- strsplit(app$get_value(export = "skip_start_event_log"), ",")[[1]]
  expect_true("anchor_timeout" %in% log)
})

# --- async-safety: stale wait_for_visible completions (Copilot review item A) ---

test_that("a stale wait_for_visible completion after $reset() does not resurrect the tour", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  # #late_visible stays hidden for 1s after this click; the anchor-ok
  # tour's wait_for_visible = 3000 is scheduled by btn_start_anchor_ok
  # below, before #late_visible becomes visible.
  app$click(input = "btn_reveal_late_visible")
  app$click(input = "btn_start_anchor_ok")
  Sys.sleep(0.3)
  app$click(input = "btn_reset_anchor_ok")

  # past the 1s reveal (so the original, now-stale wait_for_visible poll
  # has had every chance to resolve with visible = TRUE) plus a margin
  Sys.sleep(1.5)
  app$wait_for_idle()

  expect_false(app$get_js("!!document.querySelector('.driver-popover')"))
  expect_null(input_value(app, "e2e_anchor_ok_cicerone_started"))

  logs <- app$get_logs()
  errors <- logs[logs$location == "chromote" & logs$level == "error", ]
  expect_equal(nrow(errors), 0)
})

test_that("a stale wait_for_visible completion after reset+restart does not move the restarted tour", {
  skip_e2e()
  app <- e2e_app()
  on.exit(app$stop(), add = TRUE)

  # guide_anchor_race: step 1 (el1, always visible), step 2 (late_visible,
  # wait_for_visible = 2000) -- start, Next onto the waiting step 2, then
  # reset and restart immediately (well within the 2000ms wait), and only
  # THEN reveal #late_visible. The original Next click's wait_for_visible
  # poll is still in flight when it resolves visible = TRUE; it must not
  # move the freshly restarted tour.
  app$click(input = "btn_start_anchor_race")
  app$wait_for_value(input = "e2e_anchor_race_cicerone_state")
  state0 <- input_value(app, "e2e_anchor_race_cicerone_state")
  expect_equal(state0$index, 0)

  app$click(selector = ".driver-popover-next-btn")
  app$wait_for_idle()

  app$click(input = "btn_reset_anchor_race")
  app$wait_for_idle()
  app$click(input = "btn_start_anchor_race")
  # the restarted tour lands back on step 1 (index 0) -- the exact same
  # content as `state0`, so a plain wait_for_value(ignore = list(state0))
  # would never resolve; wait_for_idle() (the server round trip for this
  # click) is enough since driveNow()/destroy() are synchronous JS
  app$wait_for_idle()

  app$click(input = "btn_reveal_late_visible")
  # past the 1s reveal plus a margin, still well inside the original
  # wait's 2000ms window
  Sys.sleep(1.5)
  app$wait_for_idle()

  state <- input_value(app, "e2e_anchor_race_cicerone_state")
  expect_equal(state$index, 0)

  logs <- app$get_logs()
  errors <- logs[logs$location == "chromote" & logs$level == "error", ]
  expect_equal(nrow(errors), 0)
})
