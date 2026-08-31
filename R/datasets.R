# Module: Dataset Listing

#' List Available Imaging Datasets
#'
#' Calls \code{imagingListDatasetsDS()} on each server to retrieve the
#' list of available imaging datasets.
#'
#' @param conns DSI connections object.
#' @return Named list of per-server data.frames with available datasets.
#' @examples
#' \donttest{
#' # conns <- DSI::datashield.login(...)  # live DataSHIELD session
#' ds.imaging.datasets(conns)
#' }
#' @export
ds.imaging.datasets <- function(conns) {
  .ds_safe_aggregate(conns, expr = call("imagingListDatasetsDS"))
}
