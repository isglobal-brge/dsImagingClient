# Module: Per-Image Collection Processing Workflow
#
# The client assigns one high-level request. The server owns discovery,
# deduplication, batching, and orchestration. The assigned workflow symbol is
# used for status, recovery, and publication.

#' Process an image collection with per-image deduplication
#'
#' Assigns one disclosure-controlled collection request to each server and
#' optionally polls its server-side workflow symbol until processing completes.
#' The user can safely disconnect and reconnect with the returned symbol.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; optional dataset identifier. The server
#'   derives it from \code{handle} and verifies any supplied value.
#' @param segmenter A segmenter from ds.imaging.segmenter.*().
#' @param profile A radiomics profile from ds.imaging.radiomics.profile.*().
#' @param batch_size Integer; images per server-owned batch (default 10).
#' @param poll_interval Numeric; seconds between status checks (default 15).
#' @param timeout Numeric; max seconds to wait (default 14400 = 4 hours).
#'   Set to 0 to return immediately after kick-off (fire and forget).
#' @param visibility Compatibility argument; analytical workflows only accept
#'   \code{"private"}. Global publication is administrator-only.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @param symbol Character or NULL; target server-side workflow symbol. If NULL,
#'   a temporary symbol is generated.
#' @return A workflow submission handle when \code{timeout = 0}; otherwise the
#'   publication response.
#' @examples
#' \dontrun{
#' # conns <- DSI::datashield.login(...)  # live DataSHIELD session
#' kicked <- ds.imaging.radiomics.process_collection(
#'   conns,
#'   segmenter = ds.imaging.segmenter.existing_mask("masks"),
#'   profile = ds.imaging.radiomics.profile.demo_ct_firstorder(),
#'   timeout = 0)
#' ds.imaging.radiomics.collection_status(conns, kicked$symbol)
#' ds.imaging.radiomics.collection_publish(conns, kicked$symbol)
#' }
#' @export
ds.imaging.radiomics.process_collection <- function(conns, dataset_id = NULL,
                                             segmenter,
                                             profile = ds.imaging.radiomics.profile.ibsi_ct_3d(),
                                             batch_size = 10L,
                                             poll_interval = 15,
                                             timeout = 14400,
                                             visibility = "private",
                                             handle = "img",
                                             symbol = NULL) {
  .require_private_workflow_visibility(visibility)
  request <- list(
    handle = handle,
    dataset_id = dataset_id,
    segmenter = segmenter,
    profile = profile,
    batch_size = as.integer(batch_size)
  )
  submission <- .assign_domain_workflow(
    conns, "imagingProcessRadiomicsCollectionDS", request, symbol = symbol)

  if (timeout == 0) {
    submission$action <- "kicked_off"
    message("Collection workflow assigned as '", submission$symbol, "'.")
    return(submission)
  }

  message("Waiting for collection workflow '", submission$symbol,
          "' (Ctrl-C is safe; the server continues)...")
  start_time <- Sys.time()
  last_progress_key <- NULL

  repeat {
    status <- .collection_project(
      .collection_aggregate(
        conns, "imagingCollectionStatusDS", submission$symbol),
      c("state", "is_done", "asset_id"))
    if (length(status) == 0L) {
      .ds_first_result(status,
        paste("Collection status", submission$symbol))
    }
    if (length(status) != .collection_connection_count(conns) ||
        length(attr(status, "ds_errors")) > 0L) {
      stop("Collection status was not available from every server; ",
        "publication was not attempted.", call. = FALSE)
    }

    states <- vapply(status, function(x) {
      as.character(x$state %||% "UNKNOWN")[[1L]]
    }, character(1))
    progress_key <- paste(states, collapse = ":")

    if (!identical(progress_key, last_progress_key)) {
      message("  State: ", paste(states, collapse = ", "))
      last_progress_key <- progress_key
    }

    if (all(vapply(status, function(x) isTRUE(x$is_done), logical(1)))) {
      message("Collection processing completed.")
      break
    }

    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    if (elapsed > timeout) {
      warning("Timeout after ", round(elapsed / 60), " minutes. ",
              "The server continues processing; use collection_status() ",
              "with symbol '", submission$symbol, "'.", call. = FALSE)
      return(list(
        action = "timeout",
        symbol = submission$symbol,
        handle = handle,
        dataset_id = dataset_id,
        status = .collection_response(status,
          paste("Collection status", submission$symbol))
      ))
    }

    Sys.sleep(poll_interval)
  }

  .publish_collection(conns, submission$symbol)
}

#' Check status of a collection workflow
#'
#' Use this with the symbol returned by
#' \code{ds.imaging.radiomics.process_collection()}, including after reconnecting
#' to a session.
#'
#' @param conns DSI connections object.
#' @param symbol Character; server-side collection workflow symbol.
#' @return A list containing \code{state}, \code{is_done}, and optionally
#'   \code{asset_id}; or a named list of these responses for multiple servers.
#' @export
ds.imaging.radiomics.collection_status <- function(conns, symbol) {
  status <- .collection_project(
    .collection_aggregate(conns, "imagingCollectionStatusDS", symbol),
    c("state", "is_done", "asset_id"))
  .collection_response(status, paste("Collection status", symbol))
}

#' Recover a collection workflow
#'
#' Reconciles the server-owned workflow state and resumes eligible work.
#'
#' @param conns DSI connections object.
#' @param symbol Character; server-side collection workflow symbol.
#' @return A list containing \code{state}, \code{is_done}, and optionally
#'   \code{asset_id}; or a named list of these responses for multiple servers.
#' @export
ds.imaging.radiomics.collection_recover <- function(conns, symbol) {
  status <- .collection_project(
    .collection_aggregate(conns, "imagingCollectionRecoverDS", symbol),
    c("state", "is_done", "asset_id"))
  .collection_response(status, paste("Collection recovery", symbol))
}

#' Cancel a running collection workflow (admin only)
#'
#' Requires the server-side `dshpc.admin_key` option or `DSHPC_ADMIN_KEY`
#' environment variable. This cancels dsHPC jobs belonging to the generation and
#' marks unfinished generation items as skipped.
#'
#' @param conns DSI connections object.
#' @param symbol Character; server-side collection workflow symbol.
#' @param admin_key Character; admin key matching `dshpc.admin_key` or
#'   `DSHPC_ADMIN_KEY` on the server.
#' @param reason Character; cancellation reason.
#' @return A disclosure-controlled list containing only the coarse cancellation
#'   state.
#' @export
ds.imaging.radiomics.collection_cancel <- function(conns, symbol,
                                                   admin_key,
                                                   reason = "Cancelled by admin") {
  key_enc <- .ds_encode(list(.admin_key = admin_key))
  out <- .ds_safe_aggregate(conns, "imagingRadiomicsCancelCollectionDS",
    symbol,
    key_enc,
    .ds_encode(reason))
  .ds_first_result(out, paste("Collection cancellation", symbol))
}

#' Publish a completed collection workflow
#'
#' @param conns DSI connections object.
#' @param symbol Character; server-side collection workflow symbol.
#' @return A list containing \code{state} and \code{asset_id}; or a named list
#'   of these responses for multiple servers.
#' @export
ds.imaging.radiomics.collection_publish <- function(conns, symbol) {
  .publish_collection(conns, symbol)
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

#' @keywords internal
.collection_aggregate <- function(conns, method, symbol) {
  expr <- call(method, symbol)
  .ds_safe_aggregate(conns, expr = expr)
}

#' @keywords internal
.collection_response <- function(results, context) {
  if (length(results) == 1L) return(.ds_first_result(results, context))
  if (length(results) == 0L) .ds_first_result(results, context)
  results
}

#' @keywords internal
.collection_project <- function(results, fields) {
  errors <- attr(results, "ds_errors")
  projected <- lapply(results, function(x) {
    if (!is.list(x)) {
      stop("Collection response did not satisfy its public schema.",
           call. = FALSE)
    }
    value <- x[intersect(fields, names(x))]
    if (!is.null(value$state) &&
        (!is.character(value$state) || length(value$state) != 1L ||
         is.na(value$state) ||
         !value$state %in% c("PENDING", "RUNNING", "FINISHED", "PUBLISHED",
                             "FAILED", "CANCELLED", "ACTIVE"))) {
      stop("Collection response did not satisfy its public schema.",
           call. = FALSE)
    }
    if (!is.null(value$is_done) &&
        (!is.logical(value$is_done) || length(value$is_done) != 1L ||
         is.na(value$is_done))) {
      stop("Collection response did not satisfy its public schema.",
           call. = FALSE)
    }
    if (!is.null(value$asset_id) &&
        (!is.character(value$asset_id) || length(value$asset_id) != 1L ||
         is.na(value$asset_id) ||
         !grepl("^asset_[0-9a-f]{32}$", value$asset_id))) {
      stop("Collection response did not satisfy its public schema.",
           call. = FALSE)
    }
    value
  })
  if (length(errors) > 0L) attr(projected, "ds_errors") <- errors
  projected
}

#' @keywords internal
.collection_connection_count <- function(conns) {
  if (inherits(conns, "DSConnection")) 1L else length(conns)
}

#' @keywords internal
.publish_collection <- function(conns, symbol) {
  message("Publishing collection workflow '", symbol, "'...")
  pub <- .collection_project(
    .collection_aggregate(conns, "imagingCollectionPublishDS", symbol),
    c("state", "asset_id"))
  .collection_response(pub, paste("Collection publish", symbol))
}
