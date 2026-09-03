# Module: Radiomics Asset Discovery
# Convenience wrappers around dsImagingClient for radiomics-specific queries.

#' Legacy cross-workflow job listing
#' @param conns DSI connections object.
#' @return This function always errors. Keep the workflow symbol returned by a
#'   dsImaging submission and use its domain-specific status method instead.
#' @examples
#' \dontrun{
#' # conns <- DSI::datashield.login(...)  # live DataSHIELD session
#' ds.imaging.jobs(conns)
#' }
#' @export
ds.imaging.jobs <- function(conns) {
  stop(
    "Cross-workflow job listing is retired. Keep each dsImaging workflow ",
    "symbol and use its domain-specific status method.",
    call. = FALSE
  )
}

#' List radiomics feature tables for an initialized imaging handle
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; retained for source compatibility.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return Named list of per-server data.frames.
#' @export
ds.imaging.radiomics.features <- function(conns, dataset_id = NULL,
                                          handle = "img") {
  ds.imaging.catalog(conns, dataset_id, kind = "radiomics_collection",
    handle = handle)
}

#' List segmentation masks for an initialized imaging handle
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; retained for source compatibility.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return Named list of per-server data.frames.
#' @export
ds.imaging.masks <- function(conns, dataset_id = NULL, handle = "img") {
  ds.imaging.catalog(conns, dataset_id, kind = "mask_root", handle = handle)
}

#' Get radiomics capabilities from server
#' @param conns DSI connections object.
#' @return Named list of per-server capabilities.
#' @export
ds.imaging.capabilities <- function(conns) {
  .ds_safe_aggregate(conns, expr = call("imagingCapabilitiesDS"))
}
