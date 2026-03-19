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
  hash <- dsImaging::compute_derivation_hash(dataset_id = dataset_id, ...)
  .ds_safe_aggregate(conns,
    expr = call("imagingDeduplicateDS", dataset_id, hash))
}
