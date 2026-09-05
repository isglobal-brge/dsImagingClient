# Module: Shared Imaging Workflow Discovery

.DSIMAGING_TRACKING_KINDS <- c("analysis", "imaging")

#' @keywords internal
.imaging_tracking_plain_vector <- function(value, type, message) {
  valid <- switch(type,
    character = is.character(value),
    logical = is.logical(value),
    FALSE)
  if (!isTRUE(valid) || !is.null(dim(value))) stop(message, call. = FALSE)
  attributes(value) <- NULL
  value
}

#' List shared imaging jobs
#'
#' Lists the disclosure-safe logical queue exposed by dsHPC. One row represents
#' a whole workflow; per-image execution children, exact progress, labels,
#' owners, logs, paths, and cohort cardinality are not included. The queue is
#' node-wide, but this function returns only roots whose neutral category is
#' `imaging`; logical jobs submitted by other DataSHIELD domain packages are
#' validated and omitted.
#'
#' @param conns DSI connections object.
#' @param limit Integer server page size from 1 through 500. With `all = TRUE`,
#'   this does not limit the returned history.
#' @param cursor Optional cursor returned by a preceding single-server page.
#'   Use one server at a time for manual continuation.
#' @param all Logical; retrieve the complete imaging history by default. Set to
#'   `FALSE` to return one server page and preserve its continuation cursor.
#' @return A validated imaging-only tracking page for a single server, or a
#'   named list by server. Complete histories have `has_more = FALSE`; manual
#'   pages retain the server's `next_cursor` and `has_more` values.
#' @examples
#' \dontrun{
#' jobs <- ds.imaging.jobs(conns)
#' jobs$items
#'
#' page <- ds.imaging.jobs(conns["site1"], all = FALSE)
#' if (page$has_more) {
#'   next_page <- ds.imaging.jobs(conns["site1"], cursor = page$next_cursor,
#'     all = FALSE)
#' }
#' }
#' @export
ds.imaging.jobs <- function(conns, limit = 100L, cursor = NULL, all = TRUE) {
  if (!is.numeric(limit) || length(limit) != 1L || is.na(limit) ||
      !is.finite(limit) || limit != floor(limit) ||
      limit < 1L || limit > 500L) {
    stop("limit must be between 1 and 500.", call. = FALSE)
  }
  if (!is.logical(all) || length(all) != 1L || is.na(all)) {
    stop("all must be TRUE or FALSE.", call. = FALSE)
  }
  limit <- as.integer(limit)
  single_connection <- inherits(conns, "DSConnection")
  hosts <- if (single_connection) "default" else names(conns)
  if (!length(hosts) || anyNA(hosts) || any(!nzchar(hosts)) ||
      anyDuplicated(hosts)) {
    stop("DataSHIELD connections require non-empty, unique node names.",
      call. = FALSE)
  }
  cursor <- .imaging_validate_tracking_cursor(cursor)
  if (!is.null(cursor) && length(hosts) != 1L) {
    stop("cursor requires exactly one server connection.", call. = FALSE)
  }
  pages <- lapply(hosts, function(host) {
    connection <- if (single_connection) conns else conns[host]
    .imaging_fetch_tracking_history(connection, limit, cursor = cursor,
      all = all)
  })
  names(pages) <- hosts
  if (length(pages) == 1L) pages[[1L]] else pages
}

#' @keywords internal
.imaging_fetch_tracking_history <- function(conns, limit, cursor = NULL,
                                            all = TRUE) {
  seen_cursors <- character(0)
  seen_ids <- character(0)
  items <- list()
  page <- NULL
  repeat {
    if (!is.null(cursor)) {
      if (cursor %in% seen_cursors) {
        stop("Job listing returned a replayed cursor.", call. = FALSE)
      }
      seen_cursors <- c(seen_cursors, cursor)
    }
    results <- .ds_safe_aggregate(
      conns, expr = call("hpcTrackingListDS", limit, cursor))
    results <- .imaging_exact_workflow_results(
      results, conns, "Job listing")
    page <- .imaging_project_tracking_page(results[[1L]],
      expected_limit = limit)
    page_ids <- page$items$tracking_id
    if (anyDuplicated(page_ids) || any(page_ids %in% seen_ids)) {
      stop("Job listing returned duplicate tracking ids.", call. = FALSE)
    }
    seen_ids <- c(seen_ids, page_ids)
    items[[length(items) + 1L]] <- page$items[
      page$items$kind == "imaging", , drop = FALSE]
    if (isTRUE(page$has_more) && page$next_cursor %in% seen_cursors) {
      stop("Job listing returned a replayed cursor.", call. = FALSE)
    }
    if (!isTRUE(all) || !isTRUE(page$has_more)) break
    cursor <- page$next_cursor
  }
  combined <- do.call(rbind, items)
  rownames(combined) <- NULL
  list(items = combined,
       next_cursor = if (isTRUE(all)) NULL else page$next_cursor,
       has_more = if (isTRUE(all)) FALSE else page$has_more,
       schema = "root_v1")
}

#' @keywords internal
.imaging_validate_tracking_cursor <- function(cursor) {
  if (is.null(cursor)) return(NULL)
  cursor <- .imaging_tracking_plain_vector(cursor, "character",
    "A valid job-listing cursor is required.")
  valid <- length(cursor) == 1L && !is.na(cursor) &&
    grepl(paste0("^cur_[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-",
      "[89ab][0-9a-f]{3}-[0-9a-f]{12}$"), cursor)
  if (!isTRUE(valid)) {
    stop("A valid job-listing cursor is required.", call. = FALSE)
  }
  cursor
}

#' Get one shared logical job status
#'
#' @param conns DSI connections object.
#' @param tracking_id Public tracking id returned by a workflow status or
#'   [ds.imaging.jobs()].
#' @return One coarse status for a single server, or a named list by server.
#' @export
ds.imaging.job.status <- function(conns, tracking_id) {
  single_connection <- inherits(conns, "DSConnection")
  ids <- .imaging_tracking_ids_by_server(conns, tracking_id)
  statuses <- lapply(names(ids), function(host) {
    connection <- if (single_connection) conns else conns[host]
    results <- .ds_safe_aggregate(connection,
      expr = call("hpcTrackingStatusDS", unname(ids[[host]])))
    results <- .imaging_exact_workflow_results(
      results, connection, "Job status")
    status <- .imaging_project_tracking_status(results[[1L]],
      expected_kind = "imaging")
    if (!identical(status$tracking_id, unname(ids[[host]]))) {
      stop("Job tracking returned an invalid response.", call. = FALSE)
    }
    status
  })
  names(statuses) <- names(ids)
  if (length(statuses) == 1L) statuses[[1L]] else statuses
}

#' @keywords internal
.imaging_validate_tracking_id <- function(value) {
  value <- .imaging_tracking_plain_vector(value, "character",
    "A valid public tracking id is required.")
  valid <- length(value) == 1L && !is.na(value) &&
    grepl(paste0("^trk_[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-",
                 "[89ab][0-9a-f]{3}-[0-9a-f]{12}$"), value)
  if (!isTRUE(valid)) {
    stop("A valid public tracking id is required.", call. = FALSE)
  }
  value
}

#' @keywords internal
.imaging_project_tracking_status <- function(value, expected_kind = NULL) {
  required <- c("tracking_id", "state", "is_done", "kind")
  fields <- names(value)
  if (!is.list(value) || is.object(value) ||
      !is.character(fields) || !is.null(attributes(fields)) ||
      anyNA(fields) || anyDuplicated(fields) ||
      !setequal(fields, required)) {
    stop("Job tracking returned an invalid response.", call. = FALSE)
  }
  tracking_id <- .imaging_tracking_plain_vector(value$tracking_id,
    "character", "Job tracking returned an invalid response.")
  state <- .imaging_tracking_plain_vector(value$state, "character",
    "Job tracking returned an invalid response.")
  is_done <- .imaging_tracking_plain_vector(value$is_done, "logical",
    "Job tracking returned an invalid response.")
  kind <- .imaging_tracking_plain_vector(value$kind, "character",
    "Job tracking returned an invalid response.")
  valid <- length(tracking_id) == 1L && !is.na(tracking_id) &&
    grepl(paste0("^trk_[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-",
                 "[89ab][0-9a-f]{3}-[0-9a-f]{12}$"), tracking_id) &&
    length(state) == 1L && !is.na(state) &&
    state %in% c("queued", "running", "terminal") &&
    length(is_done) == 1L && !is.na(is_done) &&
    identical(is_done, identical(state, "terminal")) &&
    length(kind) == 1L && !is.na(kind) &&
    kind %in% .DSIMAGING_TRACKING_KINDS &&
    (is.null(expected_kind) || identical(kind, expected_kind))
  if (!isTRUE(valid)) {
    stop("Job tracking returned an invalid response.", call. = FALSE)
  }
  list(tracking_id = tracking_id, state = state, is_done = is_done,
    kind = kind)
}

#' @keywords internal
.imaging_project_tracking_page <- function(value, expected_limit = NULL) {
  required <- c("items", "next_cursor", "has_more", "schema")
  fields <- names(value)
  if (!is.list(value) || is.object(value) ||
      !is.character(fields) || !is.null(attributes(fields)) ||
      anyNA(fields) || anyDuplicated(fields) ||
      !setequal(fields, required) ||
      !identical(value$schema, "root_v1") ||
      !is.logical(value$has_more) || length(value$has_more) != 1L ||
      is.na(value$has_more) || !is.data.frame(value$items) ||
      !identical(names(value$items),
        c("tracking_id", "state", "is_done", "kind"))) {
    stop("Job listing returned an invalid response.", call. = FALSE)
  }
  if (!is.null(expected_limit) &&
      (length(expected_limit) != 1L || !is.numeric(expected_limit) ||
       is.na(expected_limit) || !is.finite(expected_limit) ||
       expected_limit != floor(expected_limit) || expected_limit < 1L ||
       nrow(value$items) > expected_limit)) {
    stop("Job listing returned an invalid response.", call. = FALSE)
  }
  items <- data.frame(
    tracking_id = .imaging_tracking_plain_vector(value$items$tracking_id,
      "character", "Job listing returned an invalid response."),
    state = .imaging_tracking_plain_vector(value$items$state,
      "character", "Job listing returned an invalid response."),
    is_done = .imaging_tracking_plain_vector(value$items$is_done,
      "logical", "Job listing returned an invalid response."),
    kind = .imaging_tracking_plain_vector(value$items$kind,
      "character", "Job listing returned an invalid response."),
    stringsAsFactors = FALSE)
  if (nrow(items) > 0L) {
    rows <- lapply(seq_len(nrow(items)), function(index) {
      .imaging_project_tracking_status(as.list(items[index, , drop = FALSE]))
    })
    items <- data.frame(
      tracking_id = vapply(rows, `[[`, character(1), "tracking_id"),
      state = vapply(rows, `[[`, character(1), "state"),
      is_done = vapply(rows, `[[`, logical(1), "is_done"),
      kind = vapply(rows, `[[`, character(1), "kind"),
      stringsAsFactors = FALSE)
  }
  if (!is.null(value$next_cursor)) {
    value$next_cursor <- .imaging_tracking_plain_vector(value$next_cursor,
      "character", "Job listing returned an invalid response.")
  }
  cursor_valid <- is.null(value$next_cursor) ||
    (is.character(value$next_cursor) && length(value$next_cursor) == 1L &&
     !is.na(value$next_cursor) &&
     grepl(paste0("^cur_[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-",
       "[89ab][0-9a-f]{3}-[0-9a-f]{12}$"), value$next_cursor))
  if (!cursor_valid ||
      (isTRUE(value$has_more) && nrow(items) == 0L) ||
      (isTRUE(value$has_more) && is.null(value$next_cursor)) ||
      (!isTRUE(value$has_more) && !is.null(value$next_cursor))) {
    stop("Job listing returned an invalid response.", call. = FALSE)
  }
  list(items = items, next_cursor = value$next_cursor,
    has_more = isTRUE(value$has_more), schema = "root_v1")
}

#' List radiomics feature tables for an initialized imaging handle
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; retained for source compatibility.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return Named list of per-server data.frames.
#' @export
ds.imaging.radiomics.features <- function(conns, dataset_id = NULL,
                                          handle = "img") {
  ds.imaging.catalog(conns, dataset_id, kind = "radiomics_collection",
    handle = handle)
}

#' List segmentation masks for an initialized imaging handle
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; retained for source compatibility.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return Named list of per-server data.frames.
#' @export
ds.imaging.masks <- function(conns, dataset_id = NULL, handle = "img") {
  ds.imaging.catalog(conns, dataset_id, kind = "mask_root", handle = handle)
}

#' Get radiomics capabilities from server
#' @param conns DSI connections object.
#' @return Named list of per-server capabilities.
#' @export
ds.imaging.capabilities <- function(conns) {
  .ds_safe_aggregate(conns, expr = call("imagingCapabilitiesDS"))
}
