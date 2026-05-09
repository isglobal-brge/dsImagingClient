# Module: Per-Image Collection Processing Workflow
#
# Fire-and-forget architecture:
#   1. Client scans collection -> gets pending list
#   2. Client submits FIRST batch only -> server takes over
#   3. Server auto-submits subsequent batches via publisher drip feed
#   4. Client can disconnect safely; reconnect later to check status
#   5. When done, client publishes collection asset
#
# The user can also stay connected and watch progress via polling.

#' Process an image collection with per-image deduplication
#'
#' Scans a dataset's images, fingerprints them, kicks off per-image
#' processing jobs, and optionally waits for completion.
#'
#' The server is self-sustaining: after the first batch is submitted,
#' completed jobs automatically trigger submission of the next batch.
#' The user can safely disconnect and reconnect later.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character; dataset identifier.
#' @param segmenter A segmenter from ds.imaging.segmenter.*().
#' @param profile A radiomics profile from ds.imaging.radiomics.profile.*().
#' @param batch_size Integer; images per batch (default 10).
#' @param poll_interval Numeric; seconds between status checks (default 15).
#' @param timeout Numeric; max seconds to wait (default 14400 = 4 hours).
#'   Set to 0 to return immediately after kick-off (fire and forget).
#' @param allow_partial Logical; publish with some failures (default FALSE).
#' @param visibility Character; asset visibility (default "global").
#' @return Named list with generation_id, asset_id (if completed), summary.
#' @export
ds.imaging.radiomics.process_collection <- function(conns, dataset_id = NULL,
                                             segmenter,
                                             profile = ds.imaging.radiomics.profile.ibsi_ct_3d(),
                                             batch_size = 10L,
                                             poll_interval = 15,
                                             timeout = 14400,
                                             allow_partial = FALSE,
                                             visibility = "global") {
  # If invoked with a multi-server connections object, fan out per server.
  # Each site has its own dataset / generation / pending list, so doing it
  # otherwise silently drops sites 2..N.
  if (!inherits(conns, "DSConnection") && length(conns) > 1L) {
    out <- list()
    for (srv in names(conns)) {
      message("=== ", srv, " ===")
      out[[srv]] <- ds.imaging.radiomics.process_collection(
        conns[srv], dataset_id = dataset_id, segmenter = segmenter,
        profile = profile, batch_size = batch_size,
        poll_interval = poll_interval, timeout = timeout,
        allow_partial = allow_partial, visibility = visibility)
    }
    return(out)
  }

  # --- Step 1: Scan collection ---
  message("Scanning collection: ", dataset_id %||% "<handle dataset>")
  scan <- .ds_safe_aggregate(conns, "imagingRadiomicsScanCollectionDS",
    .ds_encode(dataset_id),
    .ds_encode(segmenter),
    .ds_encode(profile),
    .ds_encode(visibility))

  srv <- names(scan)[1]
  result <- .ds_first_result(scan, "Collection scan")

  # Already fully computed
  if (identical(result$action, "reuse_asset")) {
    message("Collection already processed: ", result$asset_id)
    return(list(
      action = "reused",
      asset_id = result$asset_id,
      generation_id = NULL,
      dataset_id = result$dataset_id %||% dataset_id,
      total = result$total,
      done = result$done,
      pending = 0L
    ))
  }

  dataset_id <- result$dataset_id %||% dataset_id
  generation_id <- result$generation_id
  pending_ids <- result$pending_ids
  fingerprints <- result$fingerprints
  content_hashes <- result$content_hashes %||% list()
  total <- result$total
  done <- result$done %||% 0L

  message("  Total: ", total, " | Already done: ", done,
          " | Pending: ", length(pending_ids))

  # Nothing to do
  if (length(pending_ids) == 0) {
    message("All images already processed. Publishing...")
    pub <- .publish_collection(conns, generation_id, dataset_id, allow_partial)
    return(pub)
  }

  # --- Step 2: Submit FIRST batch only ---
  # The server-side drip feed (publisher hook) auto-submits subsequent
  # batches as jobs complete. No client connection needed after this.
  first_batch <- pending_ids[seq_len(min(batch_size, length(pending_ids)))]
  first_fps <- fingerprints[first_batch]
  first_chs <- content_hashes[first_batch]

  message("  Submitting first batch (", length(first_batch), " images)...")
  message("  Server will auto-submit remaining batches as jobs complete.")

  .ds_safe_aggregate(conns, "imagingRadiomicsSubmitBatchDS",
    .ds_encode(generation_id),
    .ds_encode(first_batch),
    .ds_encode(segmenter),
    .ds_encode(profile),
    .ds_encode(dataset_id),
    .ds_encode(first_fps),
    .ds_encode(first_chs))

  # Fire-and-forget mode: return immediately
  if (timeout == 0) {
    message("Fire-and-forget: generation ", generation_id, " kicked off.")
    message("  Reconnect later and call ds.imaging.radiomics.collection_status() to check.")
    return(list(
      action = "kicked_off",
      generation_id = generation_id,
      dataset_id = dataset_id,
      total = total,
      submitted = length(first_batch),
      pending = length(pending_ids) - length(first_batch)
    ))
  }

  # --- Step 3: Poll until completion (optional, user can Ctrl-C safely) ---
  message("Waiting for completion (Ctrl-C is safe, server continues)...")
  start_time <- Sys.time()
  last_completed <- -1L

  repeat {
    status <- .ds_safe_aggregate(conns, "imagingRadiomicsCollectionStatusDS",
      .ds_encode(generation_id))
    st <- status[[srv]]

    if (is.null(st)) {
      Sys.sleep(poll_interval)
      next
    }

    completed <- st$completed %||% 0L
    failed <- st$failed %||% 0L
    pending <- st$pending %||% 0L

    if (completed != last_completed) {
      pct <- round(completed / total * 100)
      message("  Progress: ", completed, "/", total,
              " (", pct, "%) | Failed: ", failed, " | Pending: ", pending)
      last_completed <- completed
    }

    if (isTRUE(st$is_done)) {
      message("All jobs completed.")
      break
    }

    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    if (elapsed > timeout) {
      warning("Timeout after ", round(elapsed / 60), " minutes. ",
              completed, "/", total, " completed. ",
              "Server continues processing. Reconnect later to publish.",
              call. = FALSE)
      return(list(
        action = "timeout",
        generation_id = generation_id,
        dataset_id = dataset_id,
        total = total,
        completed = completed,
        failed = failed,
        pending = pending
      ))
    }

    Sys.sleep(poll_interval)
  }

  # --- Step 4: Publish collection ---
  pub <- .publish_collection(conns, generation_id, dataset_id, allow_partial)
  pub
}

#' Check status of a running collection processing generation
#'
#' Use this to check on a generation that was kicked off earlier,
#' especially after a fire-and-forget call or reconnecting to a session.
#'
#' @param conns DSI connections object.
#' @param generation_id Character; the generation_id from a prior kick-off.
#' @return Named list with progress info.
#' @export
ds.imaging.radiomics.collection_status <- function(conns, generation_id) {
  status <- .ds_safe_aggregate(conns, "imagingRadiomicsCollectionStatusDS",
    .ds_encode(generation_id))
  .ds_first_result(status, paste("Collection status", generation_id))
}

#' Recover a running collection generation
#'
#' Reconciles server-side job state, requeues stale claimed items left by an
#' interrupted submitter, and nudges the server-side drip-feed loop.
#'
#' @param conns DSI connections object.
#' @param generation_id Character; the generation_id.
#' @return Named list with progress info.
#' @export
ds.imaging.radiomics.collection_recover <- function(conns, generation_id) {
  status <- .ds_safe_aggregate(conns, "imagingRadiomicsRecoverCollectionDS",
    .ds_encode(generation_id))
  .ds_first_result(status, paste("Collection recovery", generation_id))
}

#' Cancel a running collection generation (admin only)
#'
#' Requires the server-side `dsjobs.admin_key` option or `DSJOBS_ADMIN_KEY`
#' environment variable. This cancels dsJobs belonging to the generation and
#' marks unfinished generation items as skipped.
#'
#' @param conns DSI connections object.
#' @param generation_id Character; the generation_id.
#' @param admin_key Character; admin key matching `dsjobs.admin_key` or
#'   `DSJOBS_ADMIN_KEY` on the server.
#' @param reason Character; cancellation reason.
#' @return Named list with cancellation counts.
#' @export
ds.imaging.radiomics.collection_cancel <- function(conns, generation_id,
                                                   admin_key,
                                                   reason = "Cancelled by admin") {
  key_enc <- .ds_encode(list(.admin_key = admin_key))
  out <- .ds_safe_aggregate(conns, "imagingRadiomicsCancelCollectionDS",
    .ds_encode(generation_id),
    key_enc,
    .ds_encode(reason))
  .ds_first_result(out, paste("Collection cancellation", generation_id))
}

#' Publish a completed collection generation
#'
#' Call this after a fire-and-forget run completes to create the
#' collection-level asset.
#'
#' @param conns DSI connections object.
#' @param generation_id Character; the generation_id.
#' @param dataset_id Character; the dataset.
#' @param allow_partial Logical; publish even with some failures.
#' @return Named list with asset_id and summary.
#' @export
ds.imaging.radiomics.collection_publish <- function(conns, generation_id,
                                             dataset_id = NULL,
                                             allow_partial = FALSE) {
  .publish_collection(conns, generation_id, dataset_id, allow_partial)
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

#' @keywords internal
.publish_collection <- function(conns, generation_id, dataset_id, allow_partial) {
  message("Publishing collection asset...")

  pub <- .ds_safe_aggregate(conns, "imagingRadiomicsPublishCollectionDS",
    .ds_encode(generation_id),
    .ds_encode(dataset_id),
    .ds_encode(allow_partial))

  result <- .ds_first_result(pub, paste("Collection publish", generation_id))

  if (is.null(result) || is.null(result$asset_id)) {
    warning("Publishing failed or returned no asset_id", call. = FALSE)
    return(list(
      action = "publish_failed",
      generation_id = generation_id,
      result = result
    ))
  }

  n_failed <- result$failed %||% 0L
  if (n_failed > 0) {
    message("  Warning: ", n_failed, " images failed: ",
            paste(result$failed_samples, collapse = ", "))
  }

  message("Published: ", result$asset_id,
          " (", result$completed, "/", result$total, " images)")

  list(
    action = "completed",
    generation_id = generation_id,
    dataset_id = dataset_id,
    asset_id = result$asset_id,
    total = result$total,
    completed = result$completed,
    failed = n_failed,
    failed_samples = result$failed_samples
  )
}

# .ds_encode and .ds_safe_aggregate moved to utils.R
