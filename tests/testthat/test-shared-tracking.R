test_that("shared output symbols are passed to dsImaging without serialization", {
  state <- list(site = "shared_asset")
  calls <- list()
  local_mocked_bindings(
    datashield.symbols = function(conns, ...) state[names(conns)],
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      calls[[length(calls) + 1L]] <<- expr
      state$site <<- unique(c(state$site, symbol))
      success("site")
      invisible(TRUE)
    },
    .package = "DSI")
  conns <- list(site = list())

  expect_true(ds.imaging.load_asset(conns, asset_symbol = "shared_asset",
    symbol = "loaded_features", handle = "img"))
  expect_true(ds.imaging.feature_view(conns, asset_symbol = "shared_asset",
    symbol = "radiomics_view", handle = "img"))

  expect_length(calls, 2L)
  expect_true(is.symbol(calls[[1L]][[3L]]))
  expect_true(is.symbol(calls[[2L]][[3L]]))
  expect_identical(as.character(calls[[1L]][[3L]]), "shared_asset")
  expect_identical(as.character(calls[[2L]][[3L]]), "shared_asset")
  expect_false(any(vapply(calls, function(expr) {
    any(grepl("B64:", as.character(expr), fixed = TRUE))
  }, logical(1))))
  expect_error(ds.imaging.load_asset(conns,
    asset_id = "asset_public", asset_symbol = "shared_asset",
    symbol = "other"), "exactly one", fixed = TRUE)
})

test_that("logical job discovery accepts only the cardinality-free root schema", {
  tracking_id <- "trk_11111111-2222-4333-8444-555555555555"
  analysis_id <- "trk_22222222-2222-4333-8444-555555555555"
  response <- list(items = data.frame(
    tracking_id = c(tracking_id, analysis_id),
    state = c("running", "terminal"), is_done = c(FALSE, TRUE),
    kind = c("imaging", "analysis"), stringsAsFactors = FALSE),
    next_cursor = NULL, has_more = FALSE, schema = "root_v1")
  local_mocked_bindings(
    datashield.aggregate = function(conns, expr) response,
    .package = "DSI")
  page <- ds.imaging.jobs(list(site = list()))
  expect_identical(names(page$items),
    c("tracking_id", "state", "is_done", "kind"))
  expect_identical(page$items$tracking_id, tracking_id)
  expect_true(all(page$items$kind == "imaging"))
  expect_false(any(c("child_count", "progress", "owner", "label") %in%
    names(page$items)))

  response$items$kind <- "analysis"
  expect_equal(nrow(ds.imaging.jobs(list(site = list()))$items), 0L)

  response$items$kind <- "collection-secret"
  expect_error(ds.imaging.jobs(list(site = list())),
    "invalid response", fixed = TRUE)

  response$items$kind <- "imaging"
  response$items$child_count <- 128L
  expect_error(ds.imaging.jobs(list(site = list())),
    "invalid response", fixed = TRUE)

  response$items <- response$items[0, c(
    "tracking_id", "state", "is_done", "kind"), drop = FALSE]
  response$next_cursor <- "cur_11111111-2222-4333-8444-555555555555"
  response$has_more <- TRUE
  expect_error(ds.imaging.jobs(list(site = list())),
    "invalid response", fixed = TRUE)

  response$items <- data.frame(
    tracking_id = tracking_id, state = "terminal", is_done = FALSE,
    kind = "imaging", stringsAsFactors = FALSE)
  response$next_cursor <- NULL
  response$has_more <- FALSE
  expect_error(ds.imaging.jobs(list(site = list())),
    "invalid response", fixed = TRUE)
  expect_error(ds.imaging.jobs(list(site = list()), limit = 1.5),
    "between 1 and 500", fixed = TRUE)
  expect_error(ds.imaging.jobs(list(list())),
    "non-empty, unique node names", fixed = TRUE)
})

test_that("logical job discovery rejects oversized pages and strips cursors", {
  ids <- vapply(seq_len(3L), function(index) sprintf(
    "trk_%08x-2222-4333-8444-555555555555", index), character(1))
  cursor <- structure("cur_11111111-2222-4333-8444-555555555555",
    secret = "cohort-cursor")
  response <- list(items = data.frame(
    tracking_id = ids, state = "running", is_done = FALSE, kind = "imaging",
    stringsAsFactors = FALSE), next_cursor = NULL, has_more = FALSE,
    schema = "root_v1")
  local_mocked_bindings(
    datashield.aggregate = function(conns, expr) response,
    .package = "DSI")
  expect_error(ds.imaging.jobs(list(site = list()), limit = 2L),
    "invalid response", fixed = TRUE)

  response$items <- response$items[1L, , drop = FALSE]
  response$next_cursor <- cursor
  response$has_more <- TRUE
  page <- ds.imaging.jobs(list(site = list()), limit = 2L, all = FALSE)
  expect_null(attr(page$next_cursor, "secret"))
})

test_that("logical tracking schemas reject duplicate field names", {
  tracking_id <- "trk_11111111-2222-4333-8444-555555555555"
  status <- list(tracking_id = tracking_id, state = "running",
    is_done = FALSE, kind = "imaging")
  names(status)[[4L]] <- "kind"
  status <- c(status, list(kind = "analysis"))
  expect_error(dsImagingClient:::.imaging_project_tracking_status(status),
    "invalid response", fixed = TRUE)

  page <- list(items = data.frame(tracking_id = tracking_id,
    state = "running", is_done = FALSE, kind = "imaging",
    stringsAsFactors = FALSE), next_cursor = NULL, has_more = FALSE,
    schema = "root_v1")
  page <- c(page, list(schema = "bad"))
  expect_error(dsImagingClient:::.imaging_project_tracking_page(page),
    "invalid response", fixed = TRUE)

  bad_empty <- list(items = data.frame(tracking_id = integer(),
    state = logical(), is_done = character(), kind = integer()),
    next_cursor = NULL, has_more = FALSE, schema = "root_v1")
  expect_error(dsImagingClient:::.imaging_project_tracking_page(bad_empty),
    "invalid response", fixed = TRUE)
})

test_that("logical job discovery follows every page beyond one hundred jobs", {
  ids <- vapply(seq_len(125L), function(index) sprintf(
    "trk_%08x-2222-4333-8444-555555555555", index), character(1))
  cursor <- "cur_11111111-2222-4333-8444-555555555555"
  calls <- list()
  local_mocked_bindings(
    datashield.aggregate = function(conns, expr) {
      calls[[length(calls) + 1L]] <<- expr
      requested_cursor <- if (is.null(expr[[3L]])) NULL else expr[[3L]]
      selected <- if (is.null(requested_cursor)) seq_len(100L) else 101:125
      list(items = data.frame(
        tracking_id = ids[selected], state = "terminal", is_done = TRUE,
        kind = ifelse(selected %% 4L == 0L, "analysis", "imaging"),
        stringsAsFactors = FALSE),
        next_cursor = if (is.null(requested_cursor)) cursor else NULL,
        has_more = is.null(requested_cursor), schema = "root_v1")
    },
    .package = "DSI")

  history <- ds.imaging.jobs(list(site = list()), limit = 100L)
  expect_identical(history$items$tracking_id,
    ids[seq_along(ids) %% 4L != 0L])
  expect_true(all(history$items$kind == "imaging"))
  expect_identical(history$has_more, FALSE)
  expect_null(history$next_cursor)
  expect_length(calls, 2L)
  expect_identical(calls[[1L]][[2L]], 100L)
  expect_identical(calls[[2L]][[3L]], cursor)
})

test_that("manual imaging pages preserve continuation and omit analysis roots", {
  ids <- vapply(seq_len(3L), function(index) sprintf(
    "trk_%08x-2222-4333-8444-555555555555", index), character(1))
  cursor <- "cur_11111111-2222-4333-8444-555555555555"
  calls <- list()
  local_mocked_bindings(
    datashield.aggregate = function(conns, expr) {
      calls[[length(calls) + 1L]] <<- expr
      requested_cursor <- expr[[3L]]
      if (is.null(requested_cursor)) {
        return(list(items = data.frame(
          tracking_id = ids[1:2], state = c("terminal", "running"),
          is_done = c(TRUE, FALSE), kind = c("analysis", "imaging"),
          stringsAsFactors = FALSE), next_cursor = cursor,
          has_more = TRUE, schema = "root_v1"))
      }
      list(items = data.frame(
        tracking_id = ids[3L], state = "terminal", is_done = TRUE,
        kind = "imaging", stringsAsFactors = FALSE), next_cursor = NULL,
        has_more = FALSE, schema = "root_v1")
    },
    .package = "DSI")

  first <- ds.imaging.jobs(list(site = list()), limit = 2L, all = FALSE)
  expect_identical(first$items$tracking_id, ids[2L])
  expect_true(first$has_more)
  expect_identical(first$next_cursor, cursor)

  second <- ds.imaging.jobs(list(site = list()), limit = 2L,
    cursor = first$next_cursor, all = FALSE)
  expect_identical(second$items$tracking_id, ids[3L])
  expect_false(second$has_more)
  expect_null(second$next_cursor)
  expect_length(calls, 2L)
  expect_identical(calls[[2L]][[3L]], cursor)

  expect_error(ds.imaging.jobs(list(a = list(), b = list()),
    cursor = cursor, all = FALSE), "exactly one server", fixed = TRUE)
  expect_error(ds.imaging.jobs(list(site = list()), cursor = "not-a-cursor"),
    "valid job-listing cursor", fixed = TRUE)
  expect_error(ds.imaging.jobs(list(site = list()), all = NA),
    "TRUE or FALSE", fixed = TRUE)
})

test_that("logical job discovery rejects cursor replay and duplicate rows", {
  first_id <- "trk_11111111-2222-4333-8444-555555555555"
  second_id <- "trk_22222222-2222-4333-8444-555555555555"
  cursor <- "cur_11111111-2222-4333-8444-555555555555"
  calls <- 0L
  local_mocked_bindings(
    datashield.aggregate = function(conns, expr) {
      calls <<- calls + 1L
      list(items = data.frame(
        tracking_id = if (calls == 1L) first_id else second_id,
        state = "running", is_done = FALSE, kind = "imaging",
        stringsAsFactors = FALSE), next_cursor = cursor,
        has_more = TRUE, schema = "root_v1")
    },
    .package = "DSI")
  expect_error(ds.imaging.jobs(list(site = list())),
    "replayed cursor", fixed = TRUE)
  calls <- 0L
  expect_error(ds.imaging.jobs(list(site = list()), cursor = cursor,
    all = FALSE), "replayed cursor", fixed = TRUE)

  calls <- 0L
  local_mocked_bindings(
    datashield.aggregate = function(conns, expr) {
      calls <<- calls + 1L
      list(items = data.frame(
        tracking_id = first_id, state = "terminal", is_done = TRUE,
        kind = "imaging", stringsAsFactors = FALSE),
        next_cursor = if (calls == 1L) cursor else NULL,
        has_more = calls == 1L, schema = "root_v1")
    },
    .package = "DSI")
  expect_error(ds.imaging.jobs(list(site = list())),
    "duplicate tracking ids", fixed = TRUE)
})

test_that("imaging job status uses the exact tracking id for every server", {
  ids <- c(
    site_a = "trk_11111111-2222-4333-8444-555555555555",
    site_b = "trk_22222222-2222-4333-8444-555555555555")
  calls <- list()
  local_mocked_bindings(
    datashield.aggregate = function(conns, expr) {
      host <- names(conns)[[1L]]
      calls[[host]] <<- expr
      list(tracking_id = unname(ids[[host]]), state = "running",
        is_done = FALSE, kind = "imaging")
    },
    .package = "DSI")

  status <- ds.imaging.job.status(
    list(site_a = list(), site_b = list()), ids)
  expect_identical(names(status), names(ids))
  expect_identical(vapply(status, `[[`, character(1), "tracking_id"), ids)
  expect_identical(vapply(calls, function(expr) expr[[2L]], character(1)), ids)

  expect_error(ds.imaging.job.status(
    list(site_a = list(), site_b = list()), unname(ids)),
    "exactly named", fixed = TRUE)

  local_mocked_bindings(
    datashield.aggregate = function(conns, expr) list(
      tracking_id = as.character(expr[[2L]]), state = "running",
      is_done = FALSE, kind = "analysis"),
    .package = "DSI")
  expect_error(ds.imaging.job.status(list(site_a = list()), ids[[1L]]),
    "invalid response", fixed = TRUE)
})

test_that("imaging job status must describe the requested root", {
  requested <- "trk_11111111-2222-4333-8444-555555555555"
  returned <- "trk_22222222-2222-4333-8444-555555555555"
  local_mocked_bindings(
    datashield.aggregate = function(conns, expr) list(
      tracking_id = returned, state = "running", is_done = FALSE,
      kind = "imaging"),
    .package = "DSI")

  expect_error(ds.imaging.job.status(list(site = list()), requested),
    "invalid response", fixed = TRUE)
})

test_that("a node named default is not treated as a scalar connection", {
  ids <- c(
    site2 = "trk_11111111-2222-4333-8444-555555555555",
    default = "trk_22222222-2222-4333-8444-555555555555")
  local_mocked_bindings(
    datashield.aggregate = function(conns, expr) {
      host <- names(conns)[[1L]]
      value <- list(items = data.frame(tracking_id = ids[[host]],
        state = "running", is_done = FALSE, kind = "imaging",
        stringsAsFactors = FALSE), next_cursor = NULL, has_more = FALSE,
        schema = "root_v1")
      stats::setNames(list(value), host)
    },
    .package = "DSI")

  jobs <- ds.imaging.jobs(list(site2 = list(), default = list()))
  expect_identical(jobs$site2$items$tracking_id, unname(ids[["site2"]]))
  expect_identical(jobs$default$items$tracking_id,
    unname(ids[["default"]]))
})

test_that("workflow submission returns its public tracking id when available", {
  tracking_id <- "trk_11111111-2222-4333-8444-555555555555"
  state <- list(site = character())
  local_mocked_bindings(
    datashield.symbols = function(conns, ...) state[names(conns)],
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      state$site <<- unique(c(state$site, symbol))
      success("site")
      invisible(TRUE)
    },
    datashield.aggregate = function(conns, expr) list(
      state = "PENDING", is_done = FALSE, tracking_id = tracking_id),
    .package = "DSI")

  submission <- dsImagingClient:::.assign_domain_workflow(
    list(site = list()), "imagingProcessAssetWorkflowDS",
    list(handle = "img", dataset_id = "study", runner = "image_preprocess",
      config = list(image_asset = "images"), output_asset = "processed"),
    symbol = "workflow")
  expect_identical(submission$tracking_id, tracking_id)
})

test_that("reserved words are not accepted as server symbols", {
  expect_error(dsImagingClient:::.imaging_validate_symbol("if"),
    "symbol beginning with a letter", fixed = TRUE)
  expect_error(dsImagingClient:::.imaging_validate_symbol("TRUE"),
    "symbol beginning with a letter", fixed = TRUE)
})

test_that("collection workflows recover by per-server tracking id and handle", {
  ids <- c(
    site_a = "trk_11111111-2222-4333-8444-555555555555",
    site_b = "trk_22222222-2222-4333-8444-555555555555")
  state <- list(site_a = "img", site_b = "img")
  calls <- list()
  local_mocked_bindings(
    datashield.symbols = function(conns, ...) state[names(conns)],
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      host <- names(conns)[[1L]]
      calls[[host]] <<- expr
      state[[host]] <<- unique(c(state[[host]], symbol))
      success(host)
      invisible(TRUE)
    },
    .package = "DSI")
  conns <- list(site_a = list(), site_b = list())

  recovered <- ds.imaging.workflow.recover(
    conns, ids, handle = "img", symbol = "recovered")
  expect_s3_class(recovered, "dsimaging_domain_submission")
  expect_identical(recovered$tracking_id, ids)
  expect_identical(names(calls), names(conns))
  for (host in names(conns)) {
    expect_identical(as.character(calls[[host]][[1L]]),
      "imagingRecoverWorkflowDS")
    expect_identical(calls[[host]][[2L]], unname(ids[[host]]))
    expect_identical(calls[[host]][[3L]], "img")
  }
  expect_error(ds.imaging.workflow.recover(
    conns, unname(ids), handle = "img", symbol = "another"),
    "exactly named", fixed = TRUE)
})
