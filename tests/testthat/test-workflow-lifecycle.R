test_that("workflow status projects one exact safe response per server", {
  calls <- list()
  conns <- list(site_a = list(), site_b = list())
  testthat::local_mocked_bindings(
    datashield.aggregate = function(conns, expr) {
      host <- names(conns)[[1L]]
      calls[[host]] <<- expr
      list(state = "FINISHED", is_done = TRUE,
        asset_id = paste0("asset_", if (host == "site_a")
          strrep("a", 32) else strrep("b", 32)),
        job_id = "must-not-cross")
    },
    .package = "DSI"
  )

  result <- ds.imaging.workflow.status(conns, "workflow")
  expect_identical(names(result), names(conns))
  expect_true(all(vapply(result, function(x)
    identical(names(x), c("state", "is_done", "asset_id")), logical(1))))
  expect_true(all(vapply(calls, function(expr)
    identical(as.character(expr[[1L]]), "imagingWorkflowStatusDS"),
    logical(1))))
  expect_true(all(vapply(calls, function(expr)
    identical(expr[[2L]], "workflow"), logical(1))))
})

test_that("workflow status requires state and terminal flag to agree", {
  expect_error(dsImagingClient:::.imaging_project_workflow_status(
    list(state = "RUNNING", is_done = TRUE)),
  "invalid response", fixed = TRUE)
  expect_error(dsImagingClient:::.imaging_project_workflow_status(
    list(state = "FAILED", is_done = FALSE)),
  "invalid response", fixed = TRUE)
})

test_that("workflow status rejects partial fields and strips attributes", {
  expect_error(dsImagingClient:::.imaging_project_workflow_status(list(
    state_private = "RUNNING", is_done_private = FALSE)),
    "invalid response", fixed = TRUE)
  expect_error(dsImagingClient:::.imaging_project_workflow_status(structure(
    list(state = "RUNNING", is_done = FALSE, state = "FAILED"),
    names = c("state", "is_done", "state"))),
    "invalid response", fixed = TRUE)

  value <- list(
    state = structure("RUNNING", private = "cohort"),
    is_done = structure(FALSE, private = "cohort"))
  projected <- dsImagingClient:::.imaging_project_workflow_status(value)
  expect_null(attr(projected$state, "private"))
  expect_null(attr(projected$is_done, "private"))
})

test_that("workflow status fails closed on one missing server response", {
  conns <- list(site_a = list(), site_b = list())
  testthat::local_mocked_bindings(
    datashield.aggregate = function(conns, expr) {
      if (identical(names(conns), "site_b")) stop("offline")
      list(state = "RUNNING", is_done = FALSE)
    },
    .package = "DSI"
  )
  expect_warning(
    expect_error(ds.imaging.workflow.status(conns, "workflow"),
      "not available from every server", fixed = TRUE),
    "site_b", fixed = TRUE)
})

test_that("workflow destroy removes only nodes with an exact ACK", {
  conns <- list(site_a = list(), site_b = list())
  state <- list(site_a = "workflow", site_b = "workflow")
  removed <- character()
  testthat::local_mocked_bindings(
    datashield.symbols = function(conns) state[names(conns)],
    datashield.assign.expr = function(conns, symbol, expr, success, error,
                                      ...) {
      host <- names(conns)[[1L]]
      if (host == "site_a") success(host) else error(host)
      invisible(TRUE)
    },
    datashield.rm = function(conns, symbol) {
      host <- names(conns)[[1L]]
      state[[host]] <<- setdiff(state[[host]], symbol)
      removed <<- c(removed, host)
      invisible(TRUE)
    },
    .package = "DSI"
  )

  expect_error(ds.imaging.workflow.destroy(conns, "workflow"),
    "site_b", fixed = TRUE)
  expect_identical(removed, "site_a")
})

test_that("workflow destroy skips successful nodes on retry", {
  conns <- list(site_a = list(), site_b = list())
  state <- list(site_a = "workflow", site_b = "workflow")
  fail_site_b <- TRUE
  attempted <- character()
  testthat::local_mocked_bindings(
    datashield.symbols = function(conns) state[names(conns)],
    datashield.assign.expr = function(conns, symbol, expr, success, error,
                                      ...) {
      host <- names(conns)[[1L]]
      attempted <<- c(attempted, host)
      if (host == "site_b" && fail_site_b) error(host) else success(host)
      invisible(TRUE)
    },
    datashield.rm = function(conns, symbol) {
      host <- names(conns)[[1L]]
      state[[host]] <<- setdiff(state[[host]], symbol)
      invisible(TRUE)
    },
    .package = "DSI"
  )

  expect_error(ds.imaging.workflow.destroy(conns, "workflow"), "site_b")
  fail_site_b <- FALSE
  expect_true(ds.imaging.workflow.destroy(conns, "workflow"))
  expect_identical(attempted, c("site_a", "site_b", "site_b"))
})

test_that("domain assignment requires every node ACK", {
  conns <- list(site_a = list(), site_b = list())
  testthat::local_mocked_bindings(
    datashield.symbols = function(conns) {
      stats::setNames(lapply(names(conns), function(x) character()),
                      names(conns))
    },
    datashield.assign.expr = function(conns, symbol, expr, success, error,
                                      ...) {
      success("site_a")
      error("site_b")
      invisible(TRUE)
    },
    .package = "DSI"
  )
  expect_error(
    dsImagingClient:::.assign_domain_workflow(
      conns, "imagingProcessAssetWorkflowDS", list(handle = "img"),
      symbol = "workflow"),
    "site_b", fixed = TRUE)
})

test_that("domain assignment reports rollback failures without hiding init", {
  conns <- list(site_a = list(), site_b = list())
  state <- list(site_a = character(), site_b = character())
  testthat::local_mocked_bindings(
    datashield.symbols = function(conns) state[names(conns)],
    datashield.assign.expr = function(conns, symbol, expr, success, error,
                                      ...) {
      method <- as.character(expr[[1L]])
      host <- names(conns)[[1L]]
      if (identical(method, "imagingWorkflowDestroyDS")) {
        error(host, "destroy failed")
      } else {
        state$site_a <<- c(state$site_a, symbol)
        success("site_a")
        error("site_b", "assignment failed")
      }
      invisible(TRUE)
    },
    .package = "DSI"
  )

  expect_warning(
    expect_error(
      dsImagingClient:::.assign_domain_workflow(
        conns, "imagingProcessAssetWorkflowDS", list(handle = "img"),
        symbol = "workflow"),
      "site_b"),
    "rollback was incomplete.*site_a:destroy"
  )
})

test_that("workflow symbols must remain visible to datashield.symbols", {
  expect_error(
    dsImagingClient:::.imaging_workflow_symbol(".workflow"),
    "valid dsImaging workflow symbol")
})

test_that("private workflow assets are assigned by their per-server ids", {
  conns <- list(site_a = list(), site_b = list())
  expressions <- list()
  removed <- character()
  status <- list(
    site_a = list(state = "FINISHED", is_done = TRUE,
      asset_id = paste0("asset_", strrep("a", 32))),
    site_b = list(state = "FINISHED", is_done = TRUE,
      asset_id = paste0("asset_", strrep("b", 32))))
  testthat::local_mocked_bindings(
    datashield.symbols = function(conns) {
      stats::setNames(lapply(names(conns), function(x) character()),
                      names(conns))
    },
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      host <- names(conns)[[1L]]
      expressions[[host]] <<- expr
      success(host)
      invisible(TRUE)
    },
    datashield.rm = function(conns, symbol) {
      removed <<- c(removed, names(conns)[[1L]])
      invisible(TRUE)
    },
    .package = "DSI"
  )

  expect_true(ds.imaging.load_asset(
    conns, asset_id = status, symbol = "features"))
  expect_length(removed, 0L)
  expect_identical(expressions$site_a[[3L]], status$site_a$asset_id)
  expect_identical(expressions$site_b[[3L]], status$site_b$asset_id)
  expect_error(ds.imaging.load_asset(
    conns, asset_id = list(site_a = status$site_a$asset_id),
    symbol = "other"), "exactly named", fixed = TRUE)
})
