# Module: Dataset Metadata

#' Get Imaging Dataset Metadata
#'
#' Calls \code{imagingMetadataDS()} on each server to retrieve
#' disclosure-safe metadata about the imaging dataset.
#'
#' @param conns DSI connections object.
#' @param handle Character; symbol name of the imaging handle
#'   (default \code{"imaging"}).
#' @return Named list of per-server metadata.
#' @export
ds.imaging.metadata <- function(conns, handle = "imaging") {
  .ds_safe_aggregate(conns, expr = call("imagingMetadataDS", handle))
}
