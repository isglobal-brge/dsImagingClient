# Module: Session-bound Workflow Lifecycle

#' Get disclosure-controlled imaging workflow status
#'
#' Returns only a coarse state and completion flag from every server. After a
#' successful private publication, each server also returns its own opaque
#' asset identifier; no dsHPC job id, bearer, path, roster, or progress count
#' crosses the DataSHIELD boundary.
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
  if (!is.list(value) || is.null(value$state) || is.null(value$is_done) ||
      !is.character(value$state) || length(value$state) != 1L ||
      is.na(value$state) || !value$state %in% allowed_states ||
      !is.logical(value$is_done) || length(value$is_done) != 1L ||
      is.na(value$is_done)) {
    stop("Workflow status returned an invalid response.", call. = FALSE)
  }
  out <- list(state = value$state, is_done = value$is_done)
  if (!is.null(value$asset_id)) {
    if (!is.character(value$asset_id) || length(value$asset_id) != 1L ||
        is.na(value$asset_id) ||
        !grepl("^asset_[0-9a-f]{32}$", value$asset_id)) {
      stop("Workflow status returned an invalid response.", call. = FALSE)
    }
    out$asset_id <- value$asset_id
  }
  out
}
