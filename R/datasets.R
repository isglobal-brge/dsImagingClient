# Module: Dataset Listing

#' Dataset registry listing (deprecated)
#'
#' Imaging access is capability-scoped to a resource initialized with
#' \code{ds.imaging.init()}. Global registry enumeration is not available.
#'
#' @param conns DSI connections object.
#' @return This function always errors with migration guidance.
#' @examples
#' \donttest{
#' # conns <- DSI::datashield.login(...)  # live DataSHIELD session
#' ds.imaging.init(conns, resource = "PROJECT.images", symbol = "img")
#' ds.imaging.metadata(conns, handle = "img")
#' }
#' @export
ds.imaging.datasets <- function(conns) {
  stop("Dataset registry listing is no longer available. Initialize an ",
    "authorized resource with ds.imaging.init(conns, resource, symbol = 'img') ",
    "and query that handle with ds.imaging.metadata() or ds.imaging.assets().",
    call. = FALSE)
}
