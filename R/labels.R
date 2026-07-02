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

#' Disclosure-controlled label distribution for an imaging dataset
#'
#' Tabulates a label column on each node and returns the per-class counts, with
#' classes below the DataSHIELD \code{nfilter.subset} threshold suppressed
#' (dropped, and only counted in the \code{suppressed_classes} attribute). The
#' image pixels never leave the node; only disclosure-safe aggregate counts do.
#' This is the imaging analogue of \code{ds.table()} on a tabular outcome.
#'
#' @param conns DSI connections object.
#' @param symbol Character; the imaging handle symbol (default "img").
#' @param column Character or NULL; the label column to tabulate. Defaults to the
#'   dataset's manifest label column, then to \code{"label"}.
#' @return Per-server list of data.frames with columns \code{label} and \code{n}.
#' @export
ds.imaging.label_distribution <- function(conns, symbol = "img", column = NULL) {
  cc <- if (is.null(column)) call("imagingLabelDistDS", symbol)
        else call("imagingLabelDistDS", symbol, column)
  DSI::datashield.aggregate(conns, cc)
}
