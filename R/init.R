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
ds.imaging.init <- function(conns, resource, symbol = "imaging") {
  res_symbol <- paste0(symbol, "_res")

  # Assign the resource on each server
  DSI::datashield.assign.resource(conns, symbol = res_symbol,
                                   resource = resource)

  # Resolve the resource to a ResourceClient
  DSI::datashield.assign.expr(
    conns,
    symbol = res_symbol,
    expr = call("as.resource.client", as.name(res_symbol))
  )

  # Create imaging handle
  DSI::datashield.assign.expr(
    conns,
    symbol = symbol,
    expr = call("imagingInitDS", res_symbol)
  )

  invisible(TRUE)
}
