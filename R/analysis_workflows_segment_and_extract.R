# Module: Segment + Extract Chained Workflow

#' Segment images then extract radiomics features
#'
#' Chains segmentation and extraction into a single job.
#' Checks for existing masks and radiomics before recomputing.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character; dataset identifier.
#' @param image_asset Character; asset_id or alias for images.
#' @param segmenter A segmenter from ds.imaging.segmenter.*().
#' @param profile A radiomics profile from ds.imaging.radiomics.profile.*().
#' @param visibility Character; job visibility label (default "private").
#' @param batch_size Integer; images per batch.
#' @param poll_interval Numeric; seconds between status checks.
#' @param timeout Numeric; max seconds to wait. Set to 0 for fire-and-forget.
#' @param allow_partial Logical; publish with some failures.
#' @return Named list with generation and asset information.
#' @export
ds.imaging.radiomics.segment_and_extract <- function(conns, dataset_id,
                                               image_asset = "images",
                                               segmenter,
                                               profile = ds.imaging.radiomics.profile.ibsi_ct_3d(),
                                               visibility = "private",
                                               batch_size = 10L,
                                               poll_interval = 15,
                                               timeout = 14400,
                                               allow_partial = FALSE) {
  ds.imaging.radiomics.process_collection(
    conns = conns,
    dataset_id = dataset_id,
    segmenter = segmenter,
    profile = profile,
    batch_size = batch_size,
    poll_interval = poll_interval,
    timeout = timeout,
    allow_partial = allow_partial,
    visibility = visibility
  )
}
