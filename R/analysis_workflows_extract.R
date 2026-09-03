# Module: Radiomics Extraction Workflow
# Uses existing masks. Highest-value, lowest-risk path.

#' Extract radiomics features from a dataset
#'
#' Checks for existing identical derivation first (deduplication).
#' If not found, submits a dsHPC job.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; optional dataset identifier. The server
#'   derives it from \code{handle} and verifies any supplied value.
#' @param image_asset Character; asset_id or alias for images (default "images").
#' @param mask_asset Character; asset_id or alias for masks.
#' @param profile A radiomics profile from ds.imaging.radiomics.profile.*().
#' @param visibility Compatibility argument; analytical workflows only accept
#'   \code{"private"}. Global publication is administrator-only.
#' @param alias Character or NULL; alias for the published feature table.
#' @param symbol Character or NULL; target server-side symbol for the workflow
#'   handle. If NULL, a temporary symbol is generated.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return A domain-mediated workflow submission handle.
#' @export
ds.imaging.radiomics.extract <- function(conns, dataset_id = NULL, image_asset = "images",
                                  mask_asset, profile = ds.imaging.radiomics.profile.ibsi_ct_3d(),
                                  visibility = "private", alias = NULL,
                                  symbol = NULL, handle = "img") {
  .require_private_workflow_visibility(visibility)
  request <- list(handle = handle, dataset_id = dataset_id, image_asset = image_asset,
    mask_asset = mask_asset, profile = profile, alias = alias)
  .assign_domain_workflow(conns, "imagingProcessRadiomicsAssetDS", request,
    symbol = symbol)
}
