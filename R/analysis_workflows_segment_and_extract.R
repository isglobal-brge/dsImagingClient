# Module: Segment + Extract Chained Workflow

#' Segment images then extract radiomics features
#'
#' Chains segmentation and extraction into a single job.
#' Checks for existing masks and radiomics before recomputing.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; optional dataset identifier. The server
#'   derives it from \code{handle} and verifies any supplied value.
#' @param image_asset Character; asset_id or alias for images.
#' @param segmenter A segmenter from ds.imaging.segmenter.*().
#' @param profile A radiomics profile from ds.imaging.radiomics.profile.*().
#' @param visibility Compatibility argument. Complete validated outputs are
#'   shared server-side; this argument cannot alter server publication policy.
#' @param batch_size Retained for source compatibility; the dedicated chained
#'   workflow is one server-owned job and does not accept client-side batches.
#' @param poll_interval Numeric; seconds between status checks.
#' @param timeout Numeric; max seconds to wait. Set to 0 for fire-and-forget.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @param symbol Character or NULL; target server-side workflow symbol.
#' @return A workflow submission when \code{timeout = 0}; otherwise its final
#'   disclosure-controlled status, or a timeout response.
#' @export
ds.imaging.radiomics.segment_and_extract <- function(conns, dataset_id = NULL,
                                               image_asset = "images",
                                               segmenter,
                                               profile = ds.imaging.radiomics.profile.ibsi_ct_3d(),
                                               visibility = "shared",
                                               batch_size = 10L,
                                               poll_interval = 15,
                                               timeout = 14400,
                                               handle = "img",
                                               symbol = NULL) {
  .require_shared_workflow_visibility(visibility)
  request <- list(
    handle = handle,
    dataset_id = dataset_id,
    image_asset = image_asset,
    segmenter = segmenter,
    profile = profile
  )
  submission <- .assign_domain_workflow(
    conns, "imagingProcessSegmentAndExtractDS", request, symbol = symbol)
  if (identical(timeout, 0) || identical(timeout, 0L)) {
    submission$action <- "kicked_off"
    return(submission)
  }
  if (!is.numeric(timeout) || length(timeout) != 1L || is.na(timeout) ||
      timeout <= 0 || !is.numeric(poll_interval) ||
      length(poll_interval) != 1L || is.na(poll_interval) ||
      poll_interval <= 0) {
    stop("timeout and poll_interval must be positive numbers.", call. = FALSE)
  }

  start_time <- Sys.time()
  repeat {
    status <- ds.imaging.workflow.status(conns, submission)
    values <- if (is.list(status) && !is.null(status$state)) list(status) else status
    if (length(values) > 0L &&
        all(vapply(values, function(x) isTRUE(x$is_done), logical(1)))) {
      return(status)
    }
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    if (elapsed > timeout) {
      warning("The server continues processing; use ds.imaging.workflow.status().",
              call. = FALSE)
      return(list(action = "timeout", symbol = submission$symbol,
                  handle = handle, dataset_id = dataset_id, status = status))
    }
    Sys.sleep(poll_interval)
  }
}
