# Module: Label Discovery
# Query available label sets for an imaging dataset.

#' Legacy label-set discovery
#'
#' Unrestricted manifest label discovery is retired. The server admits only the
#' manifest-declared label through handle-scoped workflows.
#'
#' @param conns DSI connections object.
#' @param symbol Character; the imaging handle symbol (default "img").
#' @return This function always errors with migration guidance.
#' @export
ds.imaging.labels <- function(conns, symbol = "img") {
  stop("Label-set discovery is no longer available. Use ",
    "ds.imaging.label_distribution() for the admitted manifest label.",
    call. = FALSE)
}

#' Disclosure-controlled label distribution for an imaging dataset
#'
#' Tabulates the manifest-declared label at patient level on each node. The
#' server withholds the complete distribution when any cell is below its
#' DataSHIELD \code{nfilter.tab} threshold; otherwise its privacy profile may
#' hide, bucket, or release the admitted counts. Image pixels never leave the
#' node.
#'
#' @param conns DSI connections object.
#' @param symbol Character; the imaging handle symbol (default "img").
#' @param column Character or NULL; must be the dataset's declared
#'   \code{metadata.label_col}; NULL selects that declared column.
#' @return Per-server list of data.frames with columns \code{label} and \code{n}.
#' @export
ds.imaging.label_distribution <- function(conns, symbol = "img", column = NULL) {
  cc <- if (is.null(column)) call("imagingLabelDistDS", symbol)
        else call("imagingLabelDistDS", symbol, column)
  .ds_safe_aggregate(conns, cc)
}
