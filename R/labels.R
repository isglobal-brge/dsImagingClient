# Module: Label Discovery
# Query available label sets for an imaging dataset.

#' List available label sets for an imaging dataset
#'
#' Queries the server for label sets defined in the dataset's manifest.
#' Returns label set names, types, column names, and descriptions.
#' Counts are disclosure-controlled per the server's trust profile.
#'
#' @param conns DSI connections object.
#' @param symbol Character; the imaging handle symbol (default "img").
#' @return Per-server list of data.frames with columns: name, type, columns, description.
#' @export
ds.imaging.labels <- function(conns, symbol = "img") {
  DSI::datashield.aggregate(conns,
    expr = call("imagingLabelsDS", symbol))
}
