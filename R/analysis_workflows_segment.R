# Module: Segmentation Workflow

#' Segment images in a dataset
#'
#' @param conns DSI connections object.
#' @param dataset_id Character; dataset identifier.
#' @param image_asset Character; asset_id or alias for images.
#' @param segmenter A segmenter from ds.imaging.segmenter.*().
#' @param visibility Character; job visibility label (default "private").
#' @param alias Character or NULL; alias for the published mask.
#' @param symbol Character or NULL; target server-side symbol for the workflow
#'   handle. If NULL, a temporary symbol is generated.
#' @return A domain-mediated workflow submission handle.
#' @export
ds.imaging.segment <- function(conns, dataset_id, image_asset = "images",
                                   segmenter, visibility = "private",
                                   alias = NULL, symbol = NULL) {
  request <- list(dataset_id = dataset_id, image_asset = image_asset,
    segmenter = segmenter, visibility = visibility, alias = alias,
    job_id = .generate_job_id())
  .assign_domain_workflow(conns, "imagingProcessSegmentationCollectionDS",
    request, symbol = symbol)
}
