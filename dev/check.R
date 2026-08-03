# One-shot verification for the driver.js 1.x upgrade.
# Run from the package root:
#   Rscript dev/check.R
#
# Regenerates man/ pages, runs the testthat suite, then R CMD check.

if (!requireNamespace("devtools", quietly = TRUE))
  install.packages("devtools")

message("== documenting ==")
devtools::document()

message("== testing ==")
test_res <- devtools::test()
df <- as.data.frame(test_res)
if (sum(df$failed) > 0 || sum(df$error) > 0)
  stop("Test failures - see output above")

message("== R CMD check ==")
check_res <- devtools::check(quiet = TRUE)
print(check_res)

if (length(check_res$errors) || length(check_res$warnings)) {
  stop("R CMD check reported errors/warnings - see above")
}

message("\nAll good. Try the demo app with:")
message('  shiny::runApp("inst/examples/demo")')
