test_that("use_cicerone returns the cicerone dependency", {
  dep <- use_cicerone()

  expect_s3_class(dep, "html_dependency")
  expect_equal(dep$name, "cicerone")
  expect_equal(dep$script, "cicerone.js")
  expect_equal(dep$package, "cicerone")

  # the bundle the dependency points to actually ships with the package
  expect_true(
    file.exists(system.file("packer", "cicerone.js", package = "cicerone"))
  )
})
