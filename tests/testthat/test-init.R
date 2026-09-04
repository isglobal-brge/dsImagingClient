test_that("ds.imaging.init assigns a resource and creates only an imaging handle", {
  calls <- list()
  state <- list(site = character())
  local_mocked_bindings(
    datashield.symbols = function(conns, ...) state[names(conns)],
    datashield.assign.resource = function(conns, symbol, resource, success, ...) {
      calls[[length(calls) + 1L]] <<- list(
        method = "resource", symbol = symbol, resource = resource)
      state$site <<- c(state$site, symbol, "R", "rds")
      success("site")
      invisible(TRUE)
    },
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      calls[[length(calls) + 1L]] <<- list(
        method = "expr", symbol = symbol, expr = expr)
      state$site <<- c(state$site, symbol)
      success("site")
      invisible(TRUE)
    },
    datashield.rm = function(conns, symbol, ...) {
      state[[names(conns)[[1L]]]] <<-
        setdiff(state[[names(conns)[[1L]]]], symbol)
      invisible(TRUE)
    },
    .package = "DSI"
  )

  result <- ds.imaging.init(
    list(site = NULL), resource = "PROJECT.images", symbol = "img")

  expect_true(result)
  expect_equal(vapply(calls, `[[`, character(1), "method"),
               c("resource", "expr"))
  expect_match(calls[[1L]]$symbol, "^dsIres\\.")
  expect_equal(calls[[1L]]$resource, "PROJECT.images")
  expect_equal(calls[[2L]]$symbol, "img")
  expect_identical(as.character(calls[[2L]]$expr[[1L]]), "imagingInitDS")
  expect_identical(calls[[2L]]$expr[[2L]], calls[[1L]]$symbol)
  expect_identical(state$site, "img")
  expect_false(any(vapply(calls, function(x) {
    !is.null(x$expr) && identical(as.character(x$expr[[1L]]),
                                  "flowerInitDS")
  }, logical(1))))
})

test_that("ds.imaging.init rolls back temporary and partial symbols", {
  removed <- character()
  state <- list(site_1 = character(), site_2 = character())
  local_mocked_bindings(
    datashield.symbols = function(conns, ...) state[names(conns)],
    datashield.assign.resource = function(conns, symbol, resource, success, ...) {
      for (host in names(conns)) {
        state[[host]] <<- c(state[[host]], symbol, "R", "rds")
        success(host)
      }
      invisible(TRUE)
    },
    datashield.assign.expr = function(conns, symbol, expr, success, error, ...) {
      method <- as.character(expr[[1L]])
      host <- names(conns)[[1L]]
      if (identical(method, "imagingDestroyDS")) {
        success(host)
      } else {
        state$site_1 <<- c(state$site_1, symbol)
        success("site_1")
        error("site_2", "admission failed")
      }
      invisible(TRUE)
    },
    datashield.rm = function(conns, symbol, ...) {
      host <- names(conns)[[1L]]
      state[[host]] <<- setdiff(state[[host]], symbol)
      removed <<- c(removed, symbol)
      invisible(TRUE)
    },
    .package = "DSI"
  )

  expect_error(
    ds.imaging.init(list(site_1 = NULL, site_2 = NULL), "PROJECT.images", "img"),
    "site_2")
  expect_true("img" %in% removed)
  expect_true(any(grepl("^dsIres\\.", removed)))
  expect_true(all(c("R", "rds") %in% removed))
})

test_that("ds.imaging.init does not overwrite provider transient symbols", {
  assignments <- 0L
  local_mocked_bindings(
    datashield.symbols = function(conns, ...) list(site = "R"),
    datashield.assign.resource = function(...) {
      assignments <<- assignments + 1L
    },
    .package = "DSI"
  )

  expect_error(ds.imaging.init(
    list(site = NULL), "project/folder/images", "img"), "already exists")
  expect_identical(assignments, 0L)
})

test_that("a doubly failed temporary-resource removal remains retryable", {
  state <- list(site = character())
  resource_symbol <- NULL
  resource_remove_attempts <- 0L
  fail_resource_remove <- TRUE
  local_mocked_bindings(
    datashield.symbols = function(conns, ...) state[names(conns)],
    datashield.assign.resource = function(conns, symbol, resource, success, ...) {
      resource_symbol <<- symbol
      state$site <<- unique(c(state$site, symbol))
      success("site")
      invisible(TRUE)
    },
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      method <- as.character(expr[[1L]])
      if (identical(method, "imagingInitDS")) {
        state$site <<- unique(c(state$site, symbol))
      }
      success("site")
      invisible(TRUE)
    },
    datashield.rm = function(conns, symbol, ...) {
      if (identical(symbol, resource_symbol)) {
        resource_remove_attempts <<- resource_remove_attempts + 1L
        if (isTRUE(fail_resource_remove)) {
          stop("simulated resource removal failure")
        }
      }
      state$site <<- setdiff(state$site, symbol)
      invisible(TRUE)
    },
    .package = "DSI"
  )

  expect_warning(
    expect_error(
      ds.imaging.init(list(site = NULL), "PROJECT.images", "img"),
      "Temporary imaging resource cleanup failed"),
    "initialization cleanup was incomplete")
  expect_identical(resource_remove_attempts, 2L)
  expect_identical(resource_symbol,
    dsImagingClient:::.imaging_init_resource_symbol("img"))
  expect_identical(state$site, resource_symbol)

  fail_resource_remove <- FALSE
  expect_true(ds.imaging.destroy(list(site = NULL), "img"))
  expect_identical(resource_remove_attempts, 3L)
  expect_identical(state$site, character())
})

test_that("ds.imaging.init never overwrites an existing symbol", {
  assignments <- 0L
  local_mocked_bindings(
    datashield.symbols = function(conns, ...) list(site = "img"),
    datashield.assign.resource = function(...) {
      assignments <<- assignments + 1L
    },
    .package = "DSI"
  )

  expect_error(
    ds.imaging.init(list(site = NULL), "PROJECT.images", "img"),
    "already exists")
  expect_identical(assignments, 0L)
})

test_that("ds.imaging.destroy invokes capability-aware server cleanup", {
  assigned <- NULL
  removed <- character()
  state <- list(site = "img")
  local_mocked_bindings(
    datashield.symbols = function(conns, ...) state[names(conns)],
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      assigned <<- list(symbol = symbol, expr = expr)
      success("site")
      invisible(TRUE)
    },
    datashield.rm = function(conns, symbol, ...) {
      state[[names(conns)[[1L]]]] <<- character()
      removed <<- c(removed, symbol)
      invisible(TRUE)
    },
    .package = "DSI"
  )

  expect_true(ds.imaging.destroy(list(site = NULL), "img"))
  expect_identical(assigned$symbol, "img")
  expect_identical(as.character(assigned$expr[[1L]]), "imagingDestroyDS")
  expect_identical(assigned$expr[[2L]], "img")
  expect_identical(removed, "img")
})

test_that("ds.imaging.destroy keeps failed-node symbols retryable", {
  state <- list(site_1 = "img", site_2 = "img")
  fail_site_2 <- TRUE
  removed_on <- character()
  destroyed_on <- character()
  local_mocked_bindings(
    datashield.symbols = function(conns, ...) state[names(conns)],
    datashield.assign.expr = function(conns, symbol, expr, success, error, ...) {
      host <- names(conns)[[1L]]
      destroyed_on <<- c(destroyed_on, host)
      if (identical(host, "site_2") && isTRUE(fail_site_2)) {
        error(host, "failed")
      } else {
        success(host)
      }
      invisible(TRUE)
    },
    datashield.rm = function(conns, symbol, ...) {
      host <- names(conns)[[1L]]
      state[[host]] <<- setdiff(state[[host]], symbol)
      removed_on <<- c(removed_on, host)
      invisible(TRUE)
    },
    .package = "DSI"
  )

  expect_error(
    ds.imaging.destroy(list(site_1 = NULL, site_2 = NULL), "img"),
    "site_2")
  expect_identical(removed_on, "site_1")

  fail_site_2 <- FALSE
  expect_true(ds.imaging.destroy(
    list(site_1 = NULL, site_2 = NULL), "img"))
  expect_identical(destroyed_on, c("site_1", "site_2", "site_2"))
  expect_identical(removed_on, c("site_1", "site_2"))
})

test_that("ds.imaging.destroy retries after client-side removal failure", {
  state <- list(site = "img")
  fail_remove <- TRUE
  destroy_attempts <- 0L
  local_mocked_bindings(
    datashield.symbols = function(conns, ...) state[names(conns)],
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      destroy_attempts <<- destroy_attempts + 1L
      # The server assigns an opaque tombstone back to the same symbol after
      # removing its private registry entry.
      state[[names(conns)[[1L]]]] <<- symbol
      success(names(conns)[[1L]])
      invisible(TRUE)
    },
    datashield.rm = function(conns, symbol, ...) {
      if (fail_remove) stop("simulated remove failure")
      state[[names(conns)[[1L]]]] <<- character()
      invisible(TRUE)
    },
    .package = "DSI"
  )

  expect_error(ds.imaging.destroy(list(site = NULL), "img"), "site:remove")
  expect_identical(state$site, "img")
  fail_remove <- FALSE
  expect_true(ds.imaging.destroy(list(site = NULL), "img"))
  expect_identical(state$site, character())
  expect_identical(destroy_attempts, 2L)
})

test_that("symbols hidden from datashield.symbols are rejected", {
  assignments <- 0L
  local_mocked_bindings(
    datashield.symbols = function(conns, ...) list(site = character()),
    datashield.assign.resource = function(...) assignments <<- assignments + 1L,
    .package = "DSI"
  )

  expect_error(
    ds.imaging.init(list(site = NULL), "PROJECT.images", ".img"),
    "visible DataSHIELD symbol")
  expect_identical(assignments, 0L)
  expect_match(dsImagingClient:::.generate_symbol(),
    "^[A-Za-z][A-Za-z0-9._]+$")
})
