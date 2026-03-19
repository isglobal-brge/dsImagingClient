# Module: Dataset Listing

#' List Available Imaging Datasets
#'
#' Calls \code{imagingListDatasetsDS()} on each server to retrieve the
#' list of available imaging datasets.
#'
#' @param conns DSI connections object.
#' @return Named list of per-server data.frames with available datasets.
#' @export
ds.imaging.datasets <- function(conns) {
  .ds_safe_aggregate(conns, expr = call("imagingListDatasetsDS"))
}
