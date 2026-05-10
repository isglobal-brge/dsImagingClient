# Module: Asset Catalog Client
# Query derived assets, aliases, lineage, and check deduplication.

#' List derived assets for a dataset
#'
#' Shows all registered assets (masks, radiomics tables, embeddings, etc.)
#' with their kind, description, derivation hash, and provenance summary.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character; the dataset identifier.
#' @param kind Character or NULL; filter by kind (e.g. "feature_table",
#'   "mask_root", "embedding_table").
#' @return Named list of per-server data.frames.
#' @export
ds.imaging.catalog <- function(conns, dataset_id, kind = NULL) {
  if (is.null(kind)) {
    .ds_safe_aggregate(conns, expr = call("imagingAssetCatalogDS", dataset_id))
  } else {
    .ds_safe_aggregate(conns, expr = call("imagingAssetCatalogDS", dataset_id, kind))
  }
}

#' Get full details of a specific asset
#'
#' Returns metadata, provenance (model, version, parameters), lineage
#' (parent assets), and filesystem path.
#'
#' @param conns DSI connections object.
#' @param asset_id Character; asset_id or alias name.
#' @param dataset_id Character or NULL; required when using an alias.
#' @return Named list of per-server asset details.
#' @export
ds.imaging.asset <- function(conns, asset_id, dataset_id = NULL) {
  if (is.null(dataset_id)) {
    .ds_safe_aggregate(conns, expr = call("imagingAssetDetailDS", asset_id))
  } else {
    .ds_safe_aggregate(conns,
      expr = call("imagingAssetDetailDS", asset_id, dataset_id))
  }
}

#' Load a Published Imaging Feature Asset
#'
#' Assigns a server-side feature table asset, such as a radiomics collection,
#' into the DataSHIELD session so standard analysis packages can operate on it.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character; dataset identifier.
#' @param asset_id Character; asset id or alias.
#' @param symbol Character; target server-side symbol.
#' @param columns Optional character vector of columns to keep.
#' @param include_metadata Logical; if TRUE, load feature rows joined with
#'   dataset metadata/clinical columns on `sample_id`.
#' @param syntactic_names Logical; if TRUE, repair server-side column names for
#'   formula-based DataSHIELD models.
#' @return Invisibly TRUE.
#' @export
ds.imaging.load_asset <- function(conns, dataset_id, asset_id,
                                  symbol = "imaging_features",
                                  columns = NULL,
                                  include_metadata = FALSE,
                                  syntactic_names = FALSE) {
  DSI::datashield.assign.expr(
    conns,
    symbol = symbol,
    expr = call("imagingLoadAssetDS", dataset_id, asset_id, columns,
                include_metadata, syntactic_names)
  )
  invisible(TRUE)
}

#' @rdname ds.imaging.load_asset
#' @export
ds.imaging.radiomics.load_features <- function(conns, dataset_id, asset_id,
                                               symbol = "radiomics",
                                               columns = NULL,
                                               include_metadata = FALSE,
                                               syntactic_names = FALSE) {
  ds.imaging.load_asset(conns, dataset_id = dataset_id, asset_id = asset_id,
    symbol = symbol, columns = columns, include_metadata = include_metadata,
    syntactic_names = syntactic_names)
}

#' List aliases for a dataset
#'
#' Shows human-friendly names pointing to specific asset versions.
#' Example: "default_lung_mask" -> asset_20260319_...
#'
#' @param conns DSI connections object.
#' @param dataset_id Character; the dataset identifier.
#' @return Named list of per-server data.frames.
#' @export
ds.imaging.aliases <- function(conns, dataset_id) {
  .ds_safe_aggregate(conns, expr = call("imagingAliasesDS", dataset_id))
}

#' Get derivation lineage for an asset
#'
#' Shows which parent assets this was derived from (e.g. radiomics
#' table derived from image_root + mask_root).
#'
#' @param conns DSI connections object.
#' @param asset_id Character; the asset identifier.
#' @return Named list of per-server data.frames.
#' @export
ds.imaging.lineage <- function(conns, asset_id) {
  .ds_safe_aggregate(conns, expr = call("imagingLineageDS", asset_id))
}

#' Check if a derivation already exists (deduplication)
#'
#' Before submitting a job to extract radiomics or preprocess images,
#' check if an identical derivation (same parameters, model, version)
#' already exists. If it does, skip recomputation and use the existing asset.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character; the dataset identifier.
#' @param ... Named parameters to hash (model, version, settings, mask_asset, etc.)
#' @return Named list of per-server results with $exists and $asset_id.
#' @export
ds.imaging.check_exists <- function(conns, dataset_id, ...) {
  params <- list(...)
  hash <- if (identical(names(params), "derivation_hash")) {
    params$derivation_hash
  } else {
    .compute_derivation_hash(dataset_id = dataset_id, ...)
  }
  .ds_safe_aggregate(conns,
    expr = call("imagingDeduplicateDS", dataset_id, hash))
}
