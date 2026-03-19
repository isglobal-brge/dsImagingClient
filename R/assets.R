# Module: Dataset Assets

#' List Dataset Assets
#'
#' Calls \code{imagingAssetsDS()} on each server to retrieve the names
#' and types of assets available in the imaging dataset.
#'
#' @param conns DSI connections object.
#' @param handle Character; symbol name of the imaging handle
#'   (default \code{"imaging"}).
#' @return Named list of per-server data.frames.
#' @export
ds.imaging.assets <- function(conns, handle = "imaging") {
  .ds_safe_aggregate(conns, expr = call("imagingAssetsDS", handle))
}
