# WP7 unit coverage for `wait_for_element()`: argument validation and the
# `cicerone-wait-element` payload. No tour/Cicerone object involved -- this
# must work standalone.

test_that("wait_for_element validates its arguments", {
  s <- make_session()

  expect_error(wait_for_element(1, session = s))
  expect_error(wait_for_element(c("#a", "#b"), session = s))
  expect_error(wait_for_element("#a", timeout = -1, session = s))
  expect_error(wait_for_element("#a", timeout = 0, session = s))
  expect_error(wait_for_element("#a", visible = "yes", session = s))
})

test_that("wait_for_element sends the right payload with an explicit id", {
  s <- make_session()
  out <- wait_for_element("#late", timeout = 1234, visible = FALSE, id = "my_id", session = s)

  expect_equal(s$msgs[[1]]$type, "cicerone-wait-element")
  msg <- s$msgs[[1]]$message
  expect_equal(msg$selector, "#late")
  expect_equal(msg$timeout, 1234)
  expect_false(msg$visible)
  expect_equal(msg$id, "my_id")
  expect_equal(out, "my_id")
})

test_that("wait_for_element defaults visible to TRUE and id to a sanitised selector", {
  s <- make_session()
  out <- wait_for_element("#my.selector[data-x='1']", session = s)

  msg <- s$msgs[[1]]$message
  expect_true(msg$visible)
  expect_equal(msg$timeout, 5000)
  expect_equal(
    msg$id,
    gsub("[^A-Za-z0-9]", "_", sub("^[#.]+", "", "#my.selector[data-x='1']"))
  )
  expect_equal(out, msg$id)
})

test_that("wait_for_element strips a leading '#'/'.' before sanitising the default id", {
  s <- make_session()

  expect_equal(wait_for_element("#late", session = s), "late")
  expect_equal(wait_for_element(".card", session = s), "card")
  expect_equal(wait_for_element("#a b", session = s), "a_b")
})

test_that("wait_for_element falls back to the default reactive domain", {
  s <- make_session()
  shiny::withReactiveDomain(s, wait_for_element("#late"))

  expect_equal(s$msgs[[1]]$type, "cicerone-wait-element")
})

test_that("wait_for_element works with no tour ever created", {
  s <- make_session()
  # no Cicerone$new() anywhere in this test
  id <- wait_for_element("#standalone", session = s)

  expect_equal(id, "standalone")
  expect_equal(s$msgs[[1]]$message$selector, "#standalone")
})
