test_that("position_to_side_align maps legacy positions", {
  expect_equal(
    position_to_side_align("left-center"),
    list(side = "left", align = "center")
  )
  expect_equal(
    position_to_side_align("top-right"),
    list(side = "top", align = "end")
  )
  expect_equal(
    position_to_side_align("right-bottom"),
    list(side = "right", align = "end")
  )
  expect_equal(
    position_to_side_align("bottom"),
    list(side = "bottom", align = "start")
  )
  expect_equal(
    position_to_side_align("mid-center"),
    list(side = NULL, align = "center")
  )
  expect_warning(position_to_side_align("nonsense"))
})

test_that("normalize_buttons handles logicals and vectors", {
  expect_equal(normalize_buttons(TRUE), list("next", "previous", "close"))
  expect_equal(normalize_buttons(FALSE), list())
  expect_equal(normalize_buttons("next"), list("next"))
  expect_equal(
    normalize_buttons(c("next", "close")),
    list("next", "close")
  )
  expect_null(normalize_buttons(NULL))
  expect_error(normalize_buttons("nope"))
})

test_that("position_to_side_align passes NULL through", {
  expect_equal(
    position_to_side_align(NULL),
    list(side = NULL, align = NULL)
  )
})

test_that("deprecated_arg points to the replacement", {
  expect_warning(deprecated_arg("value", "old_arg", "new_arg"), "new_arg")
  expect_null(suppressWarnings(deprecated_arg("value", "old_arg")))
  expect_silent(deprecated_arg(NULL, "old_arg"))
})

test_that("prep_element detects selectors", {
  expect_equal(prep_element("plot"), "#plot")
  expect_equal(prep_element("#plot"), "#plot")
  expect_equal(prep_element(".class"), ".class")
  expect_equal(prep_element("div span"), "div span")
})
