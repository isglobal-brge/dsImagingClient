test_that("ds.imaging.init assigns a resource and creates only an imaging handle", {
  calls <- list()
  local_mocked_bindings(
    datashield.assign.resource = function(conns, symbol, resource, ...) {
      calls[[length(calls) + 1L]] <<- list(
        method = "resource", symbol = symbol, resource = resource)
      invisible(TRUE)
    },
    datashield.assign.expr = function(conns, symbol, expr, ...) {
      calls[[length(calls) + 1L]] <<- list(
        method = "expr", symbol = symbol, expr = expr)
      invisible(TRUE)
    },
    .package = "DSI"
  )

  result <- ds.imaging.init(
    list(site = NULL), resource = "PROJECT.images", symbol = "img")

  expect_true(result)
  expect_equal(vapply(calls, `[[`, character(1), "method"),
               c("resource", "expr"))
  expect_equal(calls[[1L]]$symbol, "img")
  expect_equal(calls[[1L]]$resource, "PROJECT.images")
  expect_equal(calls[[2L]]$symbol, "img")
  expect_identical(as.character(calls[[2L]]$expr[[1L]]), "imagingInitDS")
  expect_identical(calls[[2L]]$expr[[2L]], "img")
  expect_false(any(vapply(calls, function(x) {
    !is.null(x$expr) && identical(as.character(x$expr[[1L]]),
                                  "flowerInitDS")
  }, logical(1))))
})
