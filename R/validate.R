# Module: Dataset Validation

#' Validate Imaging Dataset
#'
#' Calls \code{imagingValidateDS()} on each server to run security and
#' integrity checks on the imaging dataset.
#'
#' @param conns DSI connections object.
#' @param handle Character; symbol name of the imaging handle
#'   (default \code{"img"}).
#' @return Named list of per-server validation results.
#' @examples
#' \donttest{
#' # conns <- DSI::datashield.login(...)  # live DataSHIELD session
#' ds.imaging.init(conns, resource = "lung_ct_res", symbol = "img")
#' str(ds.imaging.validate(conns, "img"))
#' }
#' @export
ds.imaging.validate <- function(conns, handle = "img") {
  .ds_safe_aggregate(conns, expr = call("imagingValidateDS", handle))
}
