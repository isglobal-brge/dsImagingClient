# Module: Session-bound Workflow Lifecycle

#' Get disclosure-controlled imaging workflow status
#'
#' Returns only a coarse state and completion flag from every server. The
#' public tracking id can be saved and rediscovered through the shared
#' dsHPC queue. After successful publication each server also returns its own
#' opaque asset identifier; no execution-child id, path, roster, or exact
#' progress count crosses the DataSHIELD boundary.
#'
#' @param conns DSI connections object.
#' @param workflow A workflow submission returned by a \code{ds.imaging.*}
#'   function, or its server-side symbol.
#' @return One status list for a single server, or a named list by server.
#' @export
ds.imaging.workflow.status <- function(conns, workflow) {
  symbol <- .imaging_workflow_symbol(workflow)
  results <- .ds_safe_aggregate(
    conns, expr = call("imagingWorkflowStatusDS", symbol))
  results <- .imaging_exact_workflow_results(
    results, conns, "Workflow status")
  projected <- lapply(results, .imaging_project_workflow_status)
  if (length(projected) == 1L) projected[[1L]] else projected
}

#' Recover a collection workflow from a public tracking id
#'
#' Creates a new session-bound workflow reference after reconnecting. Each
#' server revalidates the tracking root against the collection authorized by
#' `handle`; the public id alone does not grant access to imaging data.
#'
#' @param conns DSI connections object.
#' @param tracking_id Public scalar tracking id, or an exactly named id for
#'   every server.
#' @param handle Character; initialized imaging handle.
#' @param symbol Character; server symbol for the recovered workflow.
#' @return A `dsimaging_domain_submission` carrying the recovered symbol and
#'   tracking id.
#' @export
ds.imaging.workflow.recover <- function(conns, tracking_id, handle = "img",
                                        symbol = NULL) {
  symbol <- symbol %||% .generate_symbol()
  symbol <- .imaging_validate_symbol(symbol)
  handle <- .imaging_validate_symbol(handle)
  .imaging_require_symbol_absent(conns, symbol)
  .imaging_require_symbol_present(conns, handle)
  ids <- .imaging_tracking_ids_by_server(conns, tracking_id)
  hosts <- names(ids)
  single_connection <- inherits(conns, "DSConnection")
  assigned <- FALSE
  on.exit({
    if (!assigned) {
      rollback <- tryCatch(
        .imaging_workflow_rollback(conns, symbol),
        error = function(e) list(failures = "rollback-state"))
      if (length(rollback$failures)) {
        tryCatch(warning(
          "dsImaging workflow recovery rollback was incomplete on: ",
          paste(rollback$failures, collapse = ", "), ".", call. = FALSE),
          error = function(e) NULL)
      }
    }
  }, add = TRUE)

  for (host in hosts) {
    connection <- if (single_connection) conns else conns[host]
    .imaging_assign_exact(connection, "dsImaging workflow recovery",
      function(success, error) {
        DSI::datashield.assign.expr(
          connection, symbol = symbol,
          expr = call("imagingRecoverWorkflowDS", ids[[host]], handle),
          success = success, error = error, errors.print = FALSE)
      })
  }
  assigned <- TRUE
  out <- list(symbol = symbol, method = "imagingRecoverWorkflowDS",
    handle = handle, dataset_id = NULL, label = "dsImaging",
    servers = hosts,
    tracking_id = if (length(ids) == 1L) unname(ids) else ids,
    submitted_at = Sys.time())
  class(out) <- c("dsimaging_domain_submission", "list")
  out
}

#' @keywords internal
.imaging_tracking_ids_by_server <- function(conns, tracking_id) {
  hosts <- if (inherits(conns, "DSConnection")) "default" else names(conns)
  if (!length(hosts) || anyNA(hosts) || any(!nzchar(hosts)) ||
      anyDuplicated(hosts)) {
    stop("DataSHIELD connections require non-empty, unique node names.",
         call. = FALSE)
  }
  if (inherits(tracking_id, "dsimaging_domain_submission")) {
    tracking_id <- tracking_id$tracking_id
  }
  if (is.character(tracking_id) && length(tracking_id) == 1L &&
      !is.na(tracking_id)) {
    ids <- stats::setNames(rep(tracking_id, length(hosts)), hosts)
  } else {
    if (!is.character(tracking_id) || is.null(names(tracking_id)) ||
        anyNA(names(tracking_id)) || any(!nzchar(names(tracking_id))) ||
        anyDuplicated(names(tracking_id)) ||
        !setequal(names(tracking_id), hosts)) {
      stop("tracking_id must provide one exactly named id per server.",
           call. = FALSE)
    }
    ids <- tracking_id[hosts]
  }
  stats::setNames(vapply(ids, .imaging_validate_tracking_id, character(1)),
                  hosts)
}

#' Destroy a completed imaging workflow reference
#'
#' Removes the session-bound workflow capability on every server. Active work
#' is retained and reported as an error; it is never silently cancelled.
#'
#' @param conns DSI connections object.
#' @param workflow A workflow submission returned by a \code{ds.imaging.*}
#'   function, or its server-side symbol.
#' @return \code{TRUE}, invisibly.
#' @export
ds.imaging.workflow.destroy <- function(conns, workflow) {
  symbol <- .imaging_workflow_symbol(workflow)
  report <- .imaging_destroy_exact(
    conns, symbol, "imagingWorkflowDestroyDS")
  if (length(report$failures)) {
    stop("dsImaging workflow destruction failed or returned no ACK on: ",
      paste(report$failures, collapse = ", "), ". Successful or already ",
      "absent nodes were skipped; active or uncertain symbols were kept for ",
      "retry. Retry ds.imaging.workflow.destroy(conns, workflow = ",
      deparse(symbol), ").", call. = FALSE)
  }
  invisible(TRUE)
}

#' @keywords internal
.imaging_exact_workflow_results <- function(results, conns, operation) {
  hosts <- if (inherits(conns, "DSConnection")) "default" else names(conns)
  errors <- attr(results, "ds_errors")
  if (length(errors) || !is.list(results) ||
      length(results) != length(hosts) || is.null(names(results)) ||
      anyNA(names(results)) || any(!nzchar(names(results))) ||
      anyDuplicated(names(results)) || !setequal(names(results), hosts) ||
      any(vapply(results, is.null, logical(1)))) {
    stop(operation, " was not available from every server.", call. = FALSE)
  }
  results[hosts]
}

#' @keywords internal
.imaging_project_workflow_status <- function(value) {
  allowed_states <- c("PENDING", "RUNNING", "FINISHED", "PUBLISHED",
    "FAILED", "CANCELLED", "ACTIVE")
  fields <- names(value)
  if (!is.list(value) || is.object(value) || !is.character(fields) ||
      !is.null(attributes(fields)) || anyNA(fields) || anyDuplicated(fields) ||
      !all(c("state", "is_done") %in% fields)) {
    stop("Workflow status returned an invalid response.", call. = FALSE)
  }
  state <- .imaging_tracking_plain_vector(value[["state", exact = TRUE]],
    "character", "Workflow status returned an invalid response.")
  is_done <- .imaging_tracking_plain_vector(value[["is_done", exact = TRUE]],
    "logical", "Workflow status returned an invalid response.")
  if (length(state) != 1L || is.na(state) || !state %in% allowed_states ||
      length(is_done) != 1L || is.na(is_done) ||
      !identical(is_done, state %in% c(
        "FINISHED", "PUBLISHED", "FAILED", "CANCELLED", "ACTIVE"))) {
    stop("Workflow status returned an invalid response.", call. = FALSE)
  }
  out <- list(state = state, is_done = is_done)
  if ("asset_id" %in% fields) {
    asset_id <- .imaging_tracking_plain_vector(
      value[["asset_id", exact = TRUE]], "character",
      "Workflow status returned an invalid response.")
    if (length(asset_id) != 1L || is.na(asset_id) ||
        !grepl("^asset_[0-9a-f]{32}$", asset_id)) {
      stop("Workflow status returned an invalid response.", call. = FALSE)
    }
    out$asset_id <- asset_id
  }
  if ("tracking_id" %in% fields) {
    tracking_id <- .imaging_tracking_plain_vector(
      value[["tracking_id", exact = TRUE]], "character",
      "Workflow status returned an invalid response.")
    if (length(tracking_id) != 1L || is.na(tracking_id) ||
        !grepl(paste0("^trk_[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-",
                      "[89ab][0-9a-f]{3}-[0-9a-f]{12}$"),
               tracking_id)) {
      stop("Workflow status returned an invalid response.", call. = FALSE)
    }
    out$tracking_id <- tracking_id
  }
  out
}
