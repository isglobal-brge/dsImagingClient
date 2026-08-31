# Module: Radiomics Asset Discovery
# Convenience wrappers around dsImagingClient for radiomics-specific queries.

#' List radiomics jobs
#' @param conns DSI connections object.
#' @return A dshpc_result; printed as a formatted job table.
#' @examples
#' \donttest{
#' # conns <- DSI::datashield.login(...)  # live DataSHIELD session
#' ds.imaging.jobs(conns)
#' }
#' @export
ds.imaging.jobs <- function(conns) {
  dsHPCClient::ds.hpc.list(conns, label = "dsImaging")
}

#' List radiomics feature tables for a dataset
#' @param conns DSI connections object.
#' @param dataset_id Character; dataset identifier.
#' @return Named list of per-server data.frames.
#' @export
ds.imaging.radiomics.features <- function(conns, dataset_id) {
  ds.imaging.catalog(conns, dataset_id, kind = "radiomics_collection")
}

#' List segmentation masks for a dataset
#' @param conns DSI connections object.
#' @param dataset_id Character; dataset identifier.
#' @return Named list of per-server data.frames.
#' @export
ds.imaging.masks <- function(conns, dataset_id) {
  ds.imaging.catalog(conns, dataset_id, kind = "mask_root")
}

#' Get radiomics capabilities from server
#' @param conns DSI connections object.
#' @return Named list of per-server capabilities.
#' @export
ds.imaging.capabilities <- function(conns) {
  .ds_safe_aggregate(conns, expr = call("imagingCapabilitiesDS"))
}
