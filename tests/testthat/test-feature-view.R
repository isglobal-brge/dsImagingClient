test_that("feature_view assigns the opaque server method per node", {
  state <- list(site1 = character(), site2 = character())
  calls <- list()
  local_mocked_bindings(
    datashield.symbols = function(conns, ...) state[names(conns)],
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      host <- names(conns)[[1L]]
      calls[[length(calls) + 1L]] <<- list(
        host = host, symbol = symbol, expr = expr)
      state[[host]] <<- unique(c(state[[host]], symbol))
      success(host)
      invisible(NULL)
    },
    .package = "DSI"
  )

  expect_true(ds.imaging.feature_view(
    list(site1 = NULL, site2 = NULL),
    asset_id = c(site1 = "asset_one", site2 = "asset_two"),
    symbol = "radiomics_view", columns = c("mean", "energy"),
    handle = "img"))

  expect_length(calls, 2L)
  expect_true(all(vapply(calls, function(call) {
    identical(as.character(call$expr[[1L]]), "imagingFeatureViewDS") &&
      identical(call$symbol, "radiomics_view") &&
      identical(call$expr[[2L]], "img")
  }, logical(1))))
  expect_identical(calls[[1L]]$expr[[3L]], "asset_one")
  expect_identical(calls[[2L]]$expr[[3L]], "asset_two")
  expect_true(is.character(calls[[1L]]$expr[[4L]]))
  expect_length(calls[[1L]]$expr[[4L]], 1L)
  expect_true(startsWith(calls[[1L]]$expr[[4L]], "B64:"))
  expect_identical(
    calls[[1L]]$expr[[4L]],
    dsImagingClient:::.ds_encode(c("mean", "energy")))
  expect_true(all(vapply(as.list(calls[[1L]]$expr)[-1L], function(value) {
    is.atomic(value) || is.symbol(value) || is.null(value)
  }, logical(1))))
})

test_that("feature_view destroy uses the registry-aware destroy method", {
  state <- list(site = "radiomics_view")
  methods <- character()
  local_mocked_bindings(
    datashield.symbols = function(conns, ...) state[names(conns)],
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      methods <<- c(methods, as.character(expr[[1L]]))
      state$site <<- unique(c(state$site, symbol))
      success("site")
      invisible(NULL)
    },
    datashield.rm = function(conns, symbol, ...) {
      state$site <<- setdiff(state$site, symbol)
      invisible(NULL)
    },
    .package = "DSI"
  )

  expect_true(ds.imaging.feature_view.destroy(
    list(site = NULL), symbol = "radiomics_view"))
  expect_identical(methods, "imagingFeatureViewDestroyDS")
  expect_identical(state$site, character())
})

test_that("partial feature_view assignment rolls back only successful nodes", {
  state <- list(site1 = character(), site2 = character())
  methods <- character()
  local_mocked_bindings(
    datashield.symbols = function(conns, ...) state[names(conns)],
    datashield.assign.expr = function(conns, symbol, expr, success, error, ...) {
      host <- names(conns)[[1L]]
      method <- as.character(expr[[1L]])
      methods <<- c(methods, paste(host, method, sep = ":"))
      if (identical(method, "imagingFeatureViewDS") &&
          identical(host, "site2")) {
        error(host, "simulated failure")
      } else {
        state[[host]] <<- unique(c(state[[host]], symbol))
        success(host)
      }
      invisible(NULL)
    },
    datashield.rm = function(conns, symbol, ...) {
      host <- names(conns)[[1L]]
      state[[host]] <<- setdiff(state[[host]], symbol)
      invisible(NULL)
    },
    .package = "DSI"
  )

  expect_error(ds.imaging.feature_view(
    list(site1 = NULL, site2 = NULL), asset_id = "asset_public",
    symbol = "radiomics_view"), "site2")
  expect_identical(state$site1, character())
  expect_identical(state$site2, character())
  expect_true("site1:imagingFeatureViewDestroyDS" %in% methods)
})
