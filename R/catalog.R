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
#' \dontrun{
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
#' \dontrun{
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
  columns_arg <- if (is.null(columns)) NULL else .ds_encode(columns)
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
          expr = call("imagingLoadAssetDS", handle, asset_ids[[host]], columns_arg,
                      include_metadata, syntactic_names),
          success = success, error = error, errors.print = FALSE)
      })
    assigned <- c(assigned, host)
  }
  assigned <- character()
  invisible(TRUE)
}

#' Create an opaque imaging feature view for dsFlower
#'
#' Assigns a complete radiomics/feature asset behind a session-bound capability.
#' Unlike \code{ds.imaging.load_asset()}, this never places a data.frame in the
#' workspace: dsFlower receives the patient mapping only through dsImaging's
#' trusted same-session resolver. Optionally, the server can join an existing
#' clinical table under the same opaque view contract.
#'
#' @param conns DSI connections object.
#' @param asset_id Character asset id/alias used on every server, a named list
#'   with one id per server, or a workflow-status result.
#' @param symbol Character; target feature-view symbol.
#' @param columns Optional public feature-column selection.
#' @param handle Character; initialized imaging handle.
#' @param clinical_symbol Character or NULL; existing server-side clinical table
#'   to join to the imaging feature asset.
#' @param clinical_id_col Character; one patient identifier per row in the
#'   external clinical table. It is joined to dsImaging's sealed patient roster.
#' @param clinical_columns Optional clinical columns to retain.
#' @param target_col Character or NULL; classification target or numeric outcome
#'   column in the external clinical table.
#' @param target_levels Optional approved vocabulary for a classification
#'   \code{target_col}; leave NULL for a numeric outcome.
#' @return Invisibly TRUE.
#' @export
ds.imaging.feature_view <- function(conns, asset_id,
                                    symbol = "imaging_features",
                                    columns = NULL, handle = "img",
                                    clinical_symbol = NULL,
                                    clinical_id_col = "patient_id",
                                    clinical_columns = NULL,
                                    target_col = NULL,
                                    target_levels = NULL) {
  asset_ids <- .imaging_asset_ids_by_server(conns, asset_id)
  columns_arg <- if (is.null(columns)) NULL else .ds_encode(columns)
  clinical_columns_arg <- if (is.null(clinical_columns)) {
    NULL
  } else {
    .ds_encode(clinical_columns)
  }
  target_levels_arg <- if (is.null(target_levels)) {
    NULL
  } else {
    .ds_encode(target_levels)
  }
  extended_contract <- !is.null(clinical_symbol) ||
    !identical(clinical_id_col, "patient_id") ||
    !is.null(clinical_columns) || !is.null(target_col) ||
    !is.null(target_levels)
  .imaging_require_symbol_absent(conns, symbol)
  assigned <- character()
  completed <- FALSE
  on.exit({
    if (!completed && length(assigned)) {
      rollback <- tryCatch(
        .imaging_destroy_exact(
          conns[assigned], symbol, "imagingFeatureViewDestroyDS"),
        error = function(e) list(failures = "feature-view-state"))
      if (length(rollback$failures)) {
        tryCatch(warning(
          "Imaging feature-view rollback was incomplete on: ",
          paste(rollback$failures, collapse = ", "),
          ". Retry ds.imaging.feature_view.destroy().", call. = FALSE),
          error = function(e) NULL)
      }
    }
  }, add = TRUE)
  for (host in names(asset_ids)) {
    .imaging_assign_exact(conns[host], "Imaging feature-view assignment",
      function(success, error) {
        expr <- if (extended_contract) {
          call("imagingFeatureViewDS", handle, asset_ids[[host]], columns_arg,
            clinical_symbol, clinical_id_col, clinical_columns_arg,
            target_col, target_levels_arg)
        } else {
          call("imagingFeatureViewDS", handle, asset_ids[[host]], columns_arg)
        }
        DSI::datashield.assign.expr(
          conns[host], symbol = symbol,
          expr = expr,
          success = success, error = error, errors.print = FALSE)
      })
    assigned <- c(assigned, host)
  }
  completed <- TRUE
  invisible(TRUE)
}

#' Destroy an opaque imaging feature view
#'
#' @param conns DSI connections object.
#' @param symbol Character; assigned feature-view symbol.
#' @return Invisibly TRUE.
#' @export
ds.imaging.feature_view.destroy <- function(
    conns, symbol = "imaging_features") {
  report <- .imaging_destroy_exact(
    conns, symbol, "imagingFeatureViewDestroyDS")
  if (length(report$failures)) {
    stop("dsImaging feature-view destruction failed on: ",
      paste(report$failures, collapse = ", "),
      ". Successful or absent nodes were skipped; retry with the same symbol.",
      call. = FALSE)
  }
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
