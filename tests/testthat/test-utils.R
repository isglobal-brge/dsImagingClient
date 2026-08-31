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

test_that(".ds_safe_aggregate warns per failed server and records ds_errors", {
  fake_conns <- list(siteX = structure(list(), class = "not_a_connection"))
  expect_warning(
    res <- dsImagingClient:::.ds_safe_aggregate(fake_conns, quote(anyCallDS())),
    "siteX")
  errs <- attr(res, "ds_errors")
  expect_false(is.null(errs))
  expect_true("siteX" %in% names(errs))
})
