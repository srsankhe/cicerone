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

  app$click(input = "btn_start_anchor_timeout")
  app$wait_for_value(input = "e2e_anchor_timeout_cicerone_state", timeout = 5000)

  state <- input_value(app, "e2e_anchor_timeout_cicerone_state")
  expect_equal(state$highlighted, "late_visible")

  app$wait_for_idle()
  log <- strsplit(app$get_value(export = "anchor_timeout_event_log"), ",")[[1]]
  expect_true("anchor_timeout" %in% log)
})
