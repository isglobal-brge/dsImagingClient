# Module: Segmentation Workflow

#' Segment images in a dataset
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; optional dataset identifier. The server
#'   derives it from \code{handle} and verifies any supplied value.
#' @param image_asset Character; asset_id or alias for images.
#' @param segmenter A segmenter from ds.imaging.segmenter.*().
#' @param visibility Compatibility argument; analytical workflows only accept
#'   \code{"private"}. Global publication is administrator-only.
#' @param alias Character or NULL; alias for the published mask.
#' @param symbol Character or NULL; target server-side symbol for the workflow
#'   handle. If NULL, a temporary symbol is generated.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return A domain-mediated workflow submission handle.
#' @export
ds.imaging.segment <- function(conns, dataset_id = NULL, image_asset = "images",
                                   segmenter, visibility = "private",
                                   alias = NULL, symbol = NULL,
                                   handle = "img") {
  .require_private_workflow_visibility(visibility)
  request <- list(handle = handle, dataset_id = dataset_id, image_asset = image_asset,
    segmenter = segmenter, alias = alias)
  .assign_domain_workflow(conns, "imagingProcessSegmentationCollectionDS",
    request, symbol = symbol)
}
