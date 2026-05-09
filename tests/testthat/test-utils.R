# Tests for dsImagingClient utility functions

test_that("null coalescing operator works", {
  expect_equal(NULL %||% "default", "default")
  expect_equal("value" %||% "default", "value")
})

test_that("first result reports DataSHIELD aggregate errors", {
  results <- list()
  attr(results, "ds_errors") <- list(opal1 = "Cannot resolve dataset")

  expect_error(
    dsImagingClient:::.ds_first_result(results, "Collection scan"),
    "Collection scan failed: opal1: Cannot resolve dataset",
    fixed = TRUE
  )
})
