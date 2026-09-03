# Module: Dataset Metadata

#' Get Imaging Dataset Metadata
#'
#' Calls \code{imagingMetadataDS()} on each server to retrieve
#' disclosure-safe metadata about the imaging dataset.
#'
#' @param conns DSI connections object.
#' @param handle Character; symbol name of the imaging handle
#'   (default \code{"img"}).
#' @return Named list of per-server metadata.
#' @examples
#' \dontrun{
#' # conns <- DSI::datashield.login(...)  # live DataSHIELD session
#' ds.imaging.init(conns, resource = "lung_ct_res", symbol = "img")
#' str(ds.imaging.metadata(conns, "img"))
#' }
#' @export
ds.imaging.metadata <- function(conns, handle = "img") {
  .ds_safe_aggregate(conns, expr = call("imagingMetadataDS", handle))
}
