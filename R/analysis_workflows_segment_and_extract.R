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
#' @param symbol Character or NULL; target server-side symbol for the workflow
#'   handle. If NULL, a temporary symbol is generated.
#' @return A domain-mediated workflow submission handle.
#' @export
ds.imaging.radiomics.segment_and_extract <- function(conns, dataset_id,
                                               image_asset = "images",
                                               segmenter,
                                               profile = ds.imaging.radiomics.profile.ibsi_ct_3d(),
                                               visibility = "private",
                                               symbol = NULL) {
  request <- list(dataset_id = dataset_id, image_asset = image_asset,
    segmenter = segmenter, profile = profile, visibility = visibility,
    job_id = .generate_job_id())
  .assign_domain_workflow(conns, "imagingProcessSegmentAndExtractDS", request,
    symbol = symbol)
}
