# Tests for dsImagingClient utility functions

test_that("null coalescing operator works", {
  expect_equal(NULL %||% "default", "default")
  expect_equal("value" %||% "default", "value")
})

test_that("first result reports DataSHIELD aggregate errors", {
  results <- list()
  attr(results, "ds_errors") <- list(
    opal1 = "remote aggregate call failed")

  expect_error(
    dsImagingClient:::.ds_first_result(results, "Collection scan"),
    "Collection scan failed: opal1: remote aggregate call failed",
    fixed = TRUE
  )
})

test_that("aggregate failures retain the node but remove remote diagnostics", {
  fake_conns <- list(siteX = structure(list(), class = "not_a_connection"))
  private <- paste(
    "/srv/private/cohort/patients.csv",
    "s3://private-bucket/studies/hidden",
    "sample_id=patient-007")
  withr::local_options(list(
    datashield.progress = TRUE,
    datashield.errors.print = TRUE,
    progress_enabled = TRUE))
  observed_options <- NULL
  testthat::local_mocked_bindings(
    datashield.aggregate = function(...) {
      observed_options <<- c(
        progress = getOption("datashield.progress"),
        errors = getOption("datashield.errors.print"),
        progress_enabled = getOption("progress_enabled"))
      if (any(observed_options)) {
        cat(private)
        message(private)
      }
      stop(private, call. = FALSE)
    },
    .package = "DSI")

  warnings <- character()
  messages <- character()
  output <- capture.output(
    res <- withCallingHandlers(
      dsImagingClient:::.ds_safe_aggregate(fake_conns, quote(anyCallDS())),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      message = function(m) {
        messages <<- c(messages, conditionMessage(m))
        invokeRestart("muffleMessage")
      }))
  errs <- attr(res, "ds_errors")
  expect_identical(observed_options,
    c(progress = FALSE, errors = FALSE, progress_enabled = FALSE))
  expect_true(isTRUE(getOption("datashield.progress")))
  expect_true(isTRUE(getOption("datashield.errors.print")))
  expect_true(isTRUE(getOption("progress_enabled")))
  expect_length(output, 0L)
  expect_length(messages, 0L)
  expect_identical(errs, list(siteX = "remote aggregate call failed"))
  expect_identical(
    warnings,
    "dsImaging remote aggregate call failed on server 'siteX'.")

  final_error <- tryCatch(
    dsImagingClient:::.ds_first_result(res, "Imaging metadata"),
    error = conditionMessage)
  public <- paste(c(output, messages, warnings, unlist(errs), final_error),
                  collapse = "\n")
  expect_false(grepl(private, public, fixed = TRUE))
  expect_false(grepl("/srv/private", public, fixed = TRUE))
  expect_false(grepl("s3://", public, fixed = TRUE))
  expect_false(grepl("patient-007", public, fixed = TRUE))
})

test_that("successful aggregate transport does not reflect remote conditions", {
  fake_conns <- list(siteX = structure(list(), class = "not_a_connection"))
  private <- "/srv/private/cohort/patient-007.nii.gz"
  testthat::local_mocked_bindings(
    datashield.aggregate = function(...) {
      warning(private, call. = FALSE)
      message(private)
      list(ok = TRUE)
    },
    .package = "DSI")

  messages <- character()
  warnings <- character()
  result <- withCallingHandlers(
    dsImagingClient:::.ds_safe_aggregate(fake_conns, quote(anyCallDS())),
    warning = function(condition) {
      warnings <<- c(warnings, conditionMessage(condition))
      invokeRestart("muffleWarning")
    },
    message = function(condition) {
      messages <<- c(messages, conditionMessage(condition))
      invokeRestart("muffleMessage")
    })
  expect_identical(result$siteX, list(ok = TRUE))
  expect_identical(warnings, "Remote dsImaging request produced a warning.")
  expect_length(messages, 0L)
  expect_false(grepl(private, paste(warnings, collapse = "\n"), fixed = TRUE))
})

test_that("aggregate transport rejects duplicate node entries", {
  conns <- list(site = list())
  testthat::local_mocked_bindings(
    datashield.aggregate = function(...) {
      structure(list(list(ok = TRUE), list(ok = FALSE)),
        names = c("site", "site"))
    },
    .package = "DSI")

  warnings <- testthat::capture_warnings(
    result <- dsImagingClient:::.ds_safe_aggregate(conns, quote(anyCallDS())))
  expect_length(result, 0L)
  expect_identical(attr(result, "ds_errors"),
    list(site = "remote aggregate call failed"))
  expect_identical(warnings,
    "dsImaging remote aggregate call failed on server 'site'.")
})

test_that("workflow assignment suppresses and restores DSI diagnostics", {
  conns <- list(siteX = list())
  private <- paste(
    "/srv/private/cohort/patients.csv",
    "s3://private-bucket/studies/hidden",
    "sample_id=patient-007")
  withr::local_options(list(
    datashield.progress = TRUE,
    datashield.errors.print = TRUE,
    progress_enabled = TRUE))
  observed_options <- NULL
  testthat::local_mocked_bindings(
    datashield.symbols = function(conns, ...) {
      stats::setNames(list(character()), names(conns))
    },
    datashield.assign.expr = function(...) {
      observed_options <<- c(
        progress = getOption("datashield.progress"),
        errors = getOption("datashield.errors.print"),
        progress_enabled = getOption("progress_enabled"))
      if (any(observed_options)) {
        cat(private)
        message(private)
      }
      stop(private, call. = FALSE)
    },
    .package = "DSI")

  messages <- character()
  condition <- NULL
  output <- capture.output(
    condition <- withCallingHandlers(
      tryCatch(
        dsImagingClient:::.assign_domain_workflow(
          conns, "imagingProcessAssetWorkflowDS",
          list(handle = "img", note = private), symbol = "workflow_private"),
        error = identity),
      message = function(m) {
        messages <<- c(messages, conditionMessage(m))
        invokeRestart("muffleMessage")
      }))

  expect_s3_class(condition, "error")
  expect_identical(observed_options,
    c(progress = FALSE, errors = FALSE, progress_enabled = FALSE))
  expect_true(isTRUE(getOption("datashield.progress")))
  expect_true(isTRUE(getOption("datashield.errors.print")))
  expect_true(isTRUE(getOption("progress_enabled")))
  expect_length(output, 0L)
  expect_length(messages, 0L)
  public <- paste(c(output, messages, conditionMessage(condition)),
                  collapse = "\n")
  expect_false(grepl(private, public, fixed = TRUE))
  expect_false(grepl("/srv/private", public, fixed = TRUE))
  expect_false(grepl("s3://", public, fixed = TRUE))
  expect_false(grepl("patient-007", public, fixed = TRUE))
})
