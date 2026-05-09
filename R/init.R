# Module: Imaging Dataset Initialization

#' Initialize Imaging Dataset Handle
#'
#' Assigns an imaging resource on each server and creates an imaging
#' handle via \code{imagingInitDS()}.
#'
#' @param conns DSI connections object.
#' @param resource Character; name of the Opal resource to assign.
#' @param symbol Character; symbol name for the imaging handle
#'   (default \code{"imaging"}).
#' @return Named list of per-server results (invisible).
#' @export
ds.imaging.init <- function(conns, resource, symbol = "img") {
  # NOTE: symbol defaults to "img" so the server-side handle key
  #   imaging_<symbol>  matches the symbols searched by
  #   imagingGetManifestDS / .resolve_ds in dsImaging
  #   ("img", "img_res", "imaging", "res").
  #
  # datashield.assign.resource() already returns a fully-initialised
  # ResourceClient (resourcer::newResourceClient is invoked server-side
  # by Opal). The earlier intermediate as.resource.client step was a
  # no-op leftover and is dropped.
  DSI::datashield.assign.resource(conns, symbol = symbol, resource = resource)

  # Build the imaging handle from the assigned resource. imagingInitDS
  # takes the SYMBOL NAME (string), not the object itself.
  DSI::datashield.assign.expr(
    conns,
    symbol = symbol,
    expr = call("imagingInitDS", symbol)
  )

  invisible(TRUE)
}
