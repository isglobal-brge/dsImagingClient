# Module: Radiomics Summary

#' Print a disclosure-safe summary of the initialized imaging resource
#' @param conns DSI connections object.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @export
ds.imaging.summary <- function(conns, handle = "img") {
  cat("=== dsImaging Summary ===\n\n")

  metadata <- ds.imaging.metadata(conns, handle = handle)
  assets <- ds.imaging.catalog(conns, handle = handle)
  servers <- intersect(names(metadata), names(assets))
  for (srv in servers) {
    item <- metadata[[srv]]
    cat("-- ", srv, " ", paste(rep("-", 40), collapse = ""), "\n", sep = "")
    if (!is.list(item)) {
      cat("  Imaging metadata unavailable\n\n")
    } else {
      dataset_id <- item$dataset_id %||% "unknown"
      modality <- item$modality %||% "unknown"
      cat("  Dataset:", dataset_id, "\n")
      cat("  Modality:", modality, "\n")
      cat("  Derived asset catalog:",
          if (is.data.frame(assets[[srv]])) "available" else "unavailable",
          "\n\n")
    }
  }
  invisible(list(metadata = metadata, assets = assets))
}
