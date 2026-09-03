# Module: Asset Catalog Client
# Query derived assets, aliases, lineage, and check deduplication.

#' List derived assets for an initialized imaging handle
#'
#' Shows all registered assets (masks, radiomics tables, embeddings, etc.)
#' with their kind, description, derivation hash, and provenance summary.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; retained for source compatibility and
#'   ignored. The dataset is resolved from \code{handle}.
#' @param kind Character or NULL; filter by kind (e.g. "feature_table",
#'   "mask_root", "embedding_table").
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return Named list of per-server data.frames.
#' @examples
#' \donttest{
#' # conns <- DSI::datashield.login(...)  # live DataSHIELD session
#' cat_res <- ds.imaging.catalog(conns, handle = "img")
#' cat_res$site1[, c("asset_id", "kind", "created_at")]
#' ds.imaging.catalog(conns, kind = "radiomics_collection", handle = "img")
#' }
#' @export
ds.imaging.catalog <- function(conns, dataset_id = NULL, kind = NULL,
                               handle = "img") {
  .ds_safe_aggregate(conns,
    expr = call("imagingAssetCatalogDS", handle, kind))
}

#' Legacy full asset detail query
#'
#' Full asset detail queries are retired because they exposed storage paths and
#' unrestricted provenance. Use the handle-scoped catalog instead.
#'
#' @param conns DSI connections object.
#' @param asset_id Character; asset_id or alias name.
#' @param dataset_id Character or NULL; required when using an alias.
#' @return This function always errors with migration guidance.
#' @export
ds.imaging.asset <- function(conns, asset_id, dataset_id = NULL) {
  stop("Full asset details are no longer available. Use the handle-scoped ",
    "ds.imaging.catalog() result or ds.imaging.load_asset().", call. = FALSE)
}

#' Load a Published Imaging Feature Asset
#'
#' Assigns a server-side feature table asset, such as a radiomics collection,
#' into the DataSHIELD session so standard analysis packages can operate on it.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; retained for source compatibility and
#'   ignored. The dataset is resolved from \code{handle}.
#' @param asset_id Character asset id/alias used on every server, a named list
#'   with one id per server, or the result of
#'   \code{ds.imaging.workflow.status()}.
#' @param symbol Character; target server-side symbol.
#' @param columns Optional character vector of columns to keep.
#' @param include_metadata Logical; if TRUE, load feature rows joined with
#'   dataset metadata/clinical columns on `sample_id`.
#' @param syntactic_names Logical; if TRUE, repair server-side column names for
#'   formula-based DataSHIELD models.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return Invisibly TRUE.
#' @examples
#' \donttest{
#' # conns <- DSI::datashield.login(...)  # live DataSHIELD session
#' ds.imaging.radiomics.load_features(conns,
#'   asset_id = "asset_20260831_134344_b7b9f89e", symbol = "radiomics",
#'   handle = "img")
#' }
#' @export
ds.imaging.load_asset <- function(conns, dataset_id = NULL, asset_id,
                                  symbol = "imaging_features",
                                  columns = NULL,
                                  include_metadata = FALSE,
                                  syntactic_names = FALSE,
                                  handle = "img") {
  asset_ids <- .imaging_asset_ids_by_server(conns, asset_id)
  .imaging_require_symbol_absent(conns, symbol)
  assigned <- character()
  on.exit({
    if (length(assigned)) {
      for (host in assigned) {
        tryCatch(DSI::datashield.rm(conns[host], symbol),
                 error = function(e) NULL)
      }
    }
  }, add = TRUE)
  for (host in names(asset_ids)) {
    .imaging_assign_exact(conns[host], "Imaging asset assignment",
      function(success, error) {
        DSI::datashield.assign.expr(
          conns[host], symbol = symbol,
          expr = call("imagingLoadAssetDS", handle, asset_ids[[host]], columns,
                      include_metadata, syntactic_names),
          success = success, error = error, errors.print = FALSE)
      })
    assigned <- c(assigned, host)
  }
  assigned <- character()
  invisible(TRUE)
}

#' @keywords internal
.imaging_asset_ids_by_server <- function(conns, asset_id) {
  hosts <- names(conns)
  if (!length(hosts) || anyNA(hosts) || any(!nzchar(hosts)) ||
      anyDuplicated(hosts)) {
    stop("DataSHIELD connections require non-empty, unique node names.",
         call. = FALSE)
  }
  if (is.list(asset_id) && !is.null(asset_id$asset_id) &&
      is.character(asset_id$asset_id)) {
    asset_id <- asset_id$asset_id
  } else if (is.list(asset_id) && length(asset_id) &&
             all(vapply(asset_id, is.list, logical(1)))) {
    asset_id <- lapply(asset_id, function(x) x$asset_id %||% NULL)
  }
  if (is.character(asset_id) && length(asset_id) == 1L &&
      !is.na(asset_id)) {
    values <- stats::setNames(rep(asset_id, length(hosts)), hosts)
  } else {
    if (!is.list(asset_id) && !is.character(asset_id)) {
      stop("asset_id must provide one opaque id or alias per server.",
           call. = FALSE)
    }
    if (is.null(names(asset_id)) || anyNA(names(asset_id)) ||
        any(!nzchar(names(asset_id))) || anyDuplicated(names(asset_id)) ||
        !setequal(names(asset_id), hosts)) {
      stop("asset_id must provide one exactly named value per server.",
           call. = FALSE)
    }
    ordered <- asset_id[hosts]
    if (!all(vapply(ordered, function(value) {
      is.character(value) && length(value) == 1L && !is.na(value)
    }, logical(1)))) {
      stop("asset_id must provide one opaque id or alias per server.",
           call. = FALSE)
    }
    values <- stats::setNames(
      vapply(ordered, as.character, character(1)), hosts)
  }
  valid <- vapply(values, function(value) {
    is.character(value) && length(value) == 1L && !is.na(value) &&
      nchar(value, type = "bytes") <= 128L &&
      grepl("^[A-Za-z0-9][A-Za-z0-9_.-]*$", value) &&
      !grepl("..", value, fixed = TRUE)
  }, logical(1))
  if (!all(valid)) {
    stop("asset_id must contain opaque ids or server-side aliases, not paths.",
         call. = FALSE)
  }
  stats::setNames(as.character(values), hosts)
}

#' @rdname ds.imaging.load_asset
#' @export
ds.imaging.radiomics.load_features <- function(conns, dataset_id = NULL,
                                               asset_id,
                                               symbol = "radiomics",
                                               columns = NULL,
                                               include_metadata = FALSE,
                                               syntactic_names = FALSE,
                                               handle = "img") {
  ds.imaging.load_asset(conns, dataset_id = dataset_id, asset_id = asset_id,
    symbol = symbol, columns = columns, include_metadata = include_metadata,
    syntactic_names = syntactic_names, handle = handle)
}

#' Legacy dataset alias listing
#'
#' Shows human-friendly names pointing to specific asset versions.
#' Example: "default_lung_mask" -> asset_20260319_...
#'
#' @param conns DSI connections object.
#' @param dataset_id Character; the dataset identifier.
#' @return This function always errors with migration guidance.
#' @export
ds.imaging.aliases <- function(conns, dataset_id) {
  stop("Dataset-wide alias listing is no longer available. Use ",
    "ds.imaging.catalog(conns, handle = 'img').", call. = FALSE)
}

#' Legacy unrestricted asset lineage query
#'
#' Shows which parent assets this was derived from (e.g. radiomics
#' table derived from image_root + mask_root).
#'
#' @param conns DSI connections object.
#' @param asset_id Character; the asset identifier.
#' @return This function always errors with migration guidance.
#' @export
ds.imaging.lineage <- function(conns, asset_id) {
  stop("Unrestricted asset lineage queries are no longer available. Use the ",
    "handle-scoped ds.imaging.catalog() result.", call. = FALSE)
}

#' Legacy client-side derivation lookup
#'
#' Before submitting a job to extract radiomics or preprocess images,
#' check if an identical derivation (same parameters, model, version)
#' already exists. If it does, skip recomputation and use the existing asset.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character; the dataset identifier.
#' @param ... Named parameters to hash (model, version, settings, mask_asset, etc.)
#' @return This function always errors with migration guidance.
#' @export
ds.imaging.check_exists <- function(conns, dataset_id, ...) {
  stop("Client-side derivation lookup is no longer available. Submit a ",
    "handle-bound ds.imaging workflow; the server performs deduplication.",
    call. = FALSE)
}
