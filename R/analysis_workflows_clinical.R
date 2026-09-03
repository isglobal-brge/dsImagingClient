# Module: Clinical Imaging Workflows
# Generic imaging jobs beyond segmentation/radiomics.
# The retained visibility arguments accept only "private"; global publication
# is an administrator-only server operation outside DataSHIELD.

#' Convert one-file DICOM samples to NIfTI images
#'
#' Submits a dsHPC-backed SimpleITK conversion job. Each admitted patient
#' sample must map to one DICOM file; multi-file series fail closed.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; optional dataset identifier. The server
#'   derives it from \code{handle} and verifies any supplied value.
#' @param dicom_asset Character; manifest asset containing DICOM series.
#' @param output_asset Character; name for the published NIfTI image asset.
#' @param converter Character; currently only `"simpleitk"`.
#' @param visibility Character; job visibility label.
#' @param alias Character or NULL; optional asset alias.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return A domain-mediated workflow submission handle.
#' @export
ds.imaging.dicom.convert <- function(conns, dataset_id = NULL,
                                     dicom_asset = "dicom",
                                     output_asset = "nifti_images",
                                     converter = "simpleitk",
                                     visibility = "private",
                                     alias = NULL,
                                     handle = "img") {
  config <- .compact_list(list(
    dicom_asset = dicom_asset,
    converter = converter
  ))
  job <- .imaging_asset_job(dataset_id, label_tag = "dicom_convert",
    runner = "dicom_convert", config = config, output_asset = output_asset,
    asset_type = "image_root", visibility = visibility, alias = alias,
    handle = handle)
  .submit_imaging_job(conns, job)
}

#' Preprocess image assets
#'
#' Supports resampling, z-score normalization, intensity clamping/windowing, and
#' float32 casting through the `image_preprocess` runner.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; optional dataset identifier. The server
#'   derives it from \code{handle} and verifies any supplied value.
#' @param image_asset Character; source image asset.
#' @param operations Character vector; operations such as `"resample"`,
#'   `"normalize"`, `"clamp"`, and `"float32"`.
#' @param spacing Numeric vector or NULL; target spacing for resampling.
#' @param lower Numeric; lower clamp/window value.
#' @param upper Numeric; upper clamp/window value.
#' @param output_asset Character; published asset name.
#' @param visibility Character; job visibility label.
#' @param alias Character or NULL; optional asset alias.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return A domain-mediated workflow submission handle.
#' @export
ds.imaging.preprocess <- function(conns, dataset_id = NULL,
                                  image_asset = "images",
                                  operations = c("float32"),
                                  spacing = NULL,
                                  lower = -1000,
                                  upper = 1000,
                                  output_asset = "preprocessed_images",
                                  visibility = "private",
                                  alias = NULL,
                                  handle = "img") {
  config <- .compact_list(list(
    image_asset = image_asset,
    operations = paste(operations, collapse = ","),
    spacing = if (!is.null(spacing)) paste(spacing, collapse = ",") else NULL,
    lower = lower,
    upper = upper
  ))
  job <- .imaging_asset_job(dataset_id, label_tag = "preprocess",
    runner = "image_preprocess", config = config, output_asset = output_asset,
    asset_type = "image_root", visibility = visibility, alias = alias,
    handle = handle)
  .submit_imaging_job(conns, job)
}

#' Run mask or ROI operations
#'
#' Supports `binarize`, `label_select`, `connected_components`, `morphology`,
#' `union`, `intersection`, `difference`, and `resample_to_image`.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; optional dataset identifier. The server
#'   derives it from \code{handle} and verifies any supplied value.
#' @param operation Character; mask operation.
#' @param mask_asset Character; primary mask asset.
#' @param mask_b_asset Character or NULL; secondary mask asset for pair ops.
#' @param reference_asset Character or NULL; image asset for resampling masks.
#' @param labels Integer vector or NULL; labels for `label_select`.
#' @param threshold Numeric; threshold for binarization.
#' @param mode Character; morphology mode.
#' @param radius Integer; morphology radius.
#' @param min_voxels Integer; minimum component size.
#' @param max_components Integer; max components to keep.
#' @param output_asset Character; published mask asset name.
#' @param visibility Character; job visibility label.
#' @param alias Character or NULL; optional asset alias.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return A domain-mediated workflow submission handle.
#' @export
ds.imaging.mask.operation <- function(conns, dataset_id = NULL, operation,
                                      mask_asset = "masks",
                                      mask_b_asset = NULL,
                                      reference_asset = "images",
                                      labels = NULL,
                                      threshold = 0,
                                      mode = "closing",
                                      radius = 1L,
                                      min_voxels = 1L,
                                      max_components = 1L,
                                      output_asset = paste0(mask_asset, "_", operation),
                                      visibility = "private",
                                      alias = NULL,
                                      handle = "img") {
  config <- .compact_list(list(
    operation = operation,
    mask_asset = mask_asset,
    mask_b_asset = mask_b_asset,
    reference_asset = reference_asset,
    labels = if (!is.null(labels)) paste(labels, collapse = ",") else NULL,
    threshold = threshold,
    mode = mode,
    radius = as.integer(radius),
    min_voxels = as.integer(min_voxels),
    max_components = as.integer(max_components)
  ))
  job <- .imaging_asset_job(dataset_id, label_tag = "mask_operation",
    runner = "mask_ops", config = config, output_asset = output_asset,
    asset_type = "mask_root", visibility = visibility, alias = alias,
    handle = handle)
  .submit_imaging_job(conns, job)
}

#' Compute image and mask QC metrics
#'
#' Produces a server-side CSV/JSON QC output with image size/spacing/intensity
#' summaries and optional mask volume/intensity summaries.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; optional dataset identifier. The server
#'   derives it from \code{handle} and verifies any supplied value.
#' @param image_asset Character; image asset to summarize.
#' @param mask_asset Character or NULL; optional mask asset.
#' @param output_asset Character; published QC asset name.
#' @param visibility Character; job visibility label.
#' @param alias Character or NULL; optional asset alias.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return A domain-mediated workflow submission handle.
#' @export
ds.imaging.qc.metrics <- function(conns, dataset_id = NULL,
                                  image_asset = "images",
                                  mask_asset = NULL,
                                  output_asset = "imaging_qc",
                                  visibility = "private",
                                  alias = NULL,
                                  handle = "img") {
  config <- .compact_list(list(
    image_asset = image_asset,
    mask_asset = mask_asset
  ))
  job <- .imaging_asset_job(dataset_id, label_tag = "qc_metrics",
    runner = "imaging_qc_metrics", config = config,
    output_asset = output_asset, asset_type = "qc_table",
    visibility = visibility, alias = alias, handle = handle)
  .submit_imaging_job(conns, job)
}

#' Convert RTSTRUCT or DICOM SEG assets into masks
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; optional dataset identifier. The server
#'   derives it from \code{handle} and verifies any supplied value.
#' @param rt_asset Character; RTSTRUCT/DICOM SEG asset or alias.
#' @param dicom_asset Character; reference DICOM series asset for RTSTRUCT.
#' @param reference_asset Character; reference image asset for DICOM SEG geometry.
#' @param rois Character vector or NULL; ROI names to convert.
#' @param output_asset Character; published mask asset name.
#' @param visibility Character; job visibility label.
#' @param alias Character or NULL; optional asset alias.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return A domain-mediated workflow submission handle.
#' @export
ds.imaging.rt.convert <- function(conns, dataset_id = NULL,
                                  rt_asset = "rt_struct",
                                  dicom_asset = "dicom",
                                  reference_asset = "images",
                                  rois = NULL,
                                  output_asset = "rt_masks",
                                  visibility = "private",
                                  alias = NULL,
                                  handle = "img") {
  stop("RT conversion is unavailable until an exact patient-sample mapping is implemented.",
       call. = FALSE)
}

#' Run RTDOSE and RTPLAN summaries
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; optional dataset identifier. The server
#'   derives it from \code{handle} and verifies any supplied value.
#' @param dose_asset Character; RTDOSE asset or alias.
#' @param plan_asset Character; RTPLAN asset or alias.
#' @param mask_asset Character or NULL; optional mask asset for dose metrics.
#' @param output_asset Character; published dose table asset name.
#' @param visibility Character; job visibility label.
#' @param alias Character or NULL; optional asset alias.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return A domain-mediated workflow submission handle.
#' @export
ds.imaging.rt.dose <- function(conns, dataset_id = NULL,
                               dose_asset = "rt_dose",
                               plan_asset = "rt_plan",
                               mask_asset = NULL,
                               output_asset = "rt_dose_metrics",
                               visibility = "private",
                               alias = NULL,
                               handle = "img") {
  stop("RT dose analysis is unavailable until an exact patient-sample mapping is implemented.",
       call. = FALSE)
}

#' Generate non-disclosive QC thumbnails and overlays
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; optional dataset identifier. The server
#'   derives it from \code{handle} and verifies any supplied value.
#' @param image_asset Character; image asset or alias.
#' @param mask_asset Character or NULL; optional mask asset.
#' @param max_size Integer; maximum PNG side length.
#' @param max_images Deprecated and ignored. The complete admitted collection
#'   is processed; arbitrary subsets are not supported.
#' @param anonymize_names Logical; must remain TRUE. Output names are always
#'   pseudonymized server-side.
#' @param output_asset Character; published QC visual asset name.
#' @param visibility Character; job visibility label.
#' @param alias Character or NULL; optional asset alias.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return A domain-mediated workflow submission handle.
#' @export
ds.imaging.qc.visuals <- function(conns, dataset_id = NULL,
                                  image_asset = "images",
                                  mask_asset = NULL,
                                  max_size = 192L,
                                  max_images = 24L,
                                  anonymize_names = TRUE,
                                  output_asset = "qc_visuals",
                                  visibility = "private",
                                  alias = NULL,
                                  handle = "img") {
  config <- .compact_list(list(
    image_asset = image_asset,
    mask_asset = mask_asset,
    max_size = as.integer(max_size)
  ))
  if (!isTRUE(anonymize_names)) {
    stop("QC visual output names must remain pseudonymized.", call. = FALSE)
  }
  if (!missing(max_images)) {
    warning("max_images is deprecated and ignored; the complete admitted collection is processed.",
            call. = FALSE)
  }
  job <- .imaging_asset_job(dataset_id, label_tag = "qc_visuals",
    runner = "imaging_qc_visuals", config = config,
    output_asset = output_asset, asset_type = "qc_visual_asset",
    visibility = visibility, alias = alias, handle = handle)
  .submit_imaging_job(conns, job)
}

#' Run spatial image operations
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; optional dataset identifier. The server
#'   derives it from \code{handle} and verifies any supplied value.
#' @param image_asset Character; source image asset.
#' @param operations Character vector; `resample`, `crop_to_mask`,
#'   `center_crop`, `n4_bias`, or `register_rigid`.
#' @param mask_asset Character or NULL; mask asset for `crop_to_mask`.
#' @param reference_asset Character or NULL; reference asset for registration.
#' @param spacing Numeric vector or NULL; target spacing for `resample`.
#' @param crop_size Integer vector or NULL; center crop size.
#' @param output_asset Character; published image asset name.
#' @param visibility Character; job visibility label.
#' @param alias Character or NULL; optional asset alias.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return A domain-mediated workflow submission handle.
#' @export
ds.imaging.spatial.process <- function(conns, dataset_id = NULL,
                                       image_asset = "images",
                                       operations = c("resample"),
                                       mask_asset = NULL,
                                       reference_asset = NULL,
                                       spacing = NULL,
                                       crop_size = NULL,
                                       output_asset = "spatial_images",
                                       visibility = "private",
                                       alias = NULL,
                                       handle = "img") {
  config <- .compact_list(list(
    image_asset = image_asset,
    operations = paste(operations, collapse = ","),
    mask_asset = mask_asset,
    reference_asset = reference_asset,
    spacing = if (!is.null(spacing)) paste(spacing, collapse = ",") else NULL,
    crop_size = if (!is.null(crop_size)) paste(crop_size, collapse = ",") else NULL
  ))
  job <- .imaging_asset_job(dataset_id, label_tag = "spatial",
    runner = "image_spatial", config = config, output_asset = output_asset,
    asset_type = "image_root", visibility = visibility, alias = alias,
    handle = handle)
  .submit_imaging_job(conns, job)
}

#' Tile WSI/pathology images
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; optional dataset identifier. The server
#'   derives it from \code{handle} and verifies any supplied value.
#' @param wsi_asset Character; WSI asset or alias.
#' @param tile_size Integer; tile side length in pixels.
#' @param stride Integer; tile stride in pixels.
#' @param max_tiles Integer; maximum tiles per site.
#' @param tissue_threshold Numeric; minimum estimated tissue fraction.
#' @param write_tiles Logical; write PNG tile files.
#' @param output_asset Character; published tile asset name.
#' @param visibility Character; job visibility label.
#' @param alias Character or NULL; optional asset alias.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return A domain-mediated workflow submission handle.
#' @export
ds.imaging.wsi.tile <- function(conns, dataset_id = NULL, wsi_asset = "wsi",
                                tile_size = 512L,
                                stride = tile_size,
                                max_tiles = 2048L,
                                tissue_threshold = 0.10,
                                write_tiles = TRUE,
                                output_asset = "wsi_tiles",
                                visibility = "private",
                                alias = NULL,
                                handle = "img") {
  stop("WSI tiling is unavailable until an exact patient-sample mapping is implemented.",
       call. = FALSE)
}

#' Extract image embeddings
#'
#' @param conns DSI connections object.
#' @param dataset_id Character or NULL; optional dataset identifier. The server
#'   derives it from \code{handle} and verifies any supplied value.
#' @param image_asset Character; image asset or alias.
#' @param model Character; embedding model name. The default is a deterministic
#'   intensity histogram baseline.
#' @param bins Integer; histogram bins for the baseline embedding.
#' @param output_asset Character; published embedding table asset name.
#' @param visibility Character; job visibility label.
#' @param alias Character or NULL; optional asset alias.
#' @param handle Character; initialized imaging handle (default \code{"img"}).
#' @return A domain-mediated workflow submission handle.
#' @export
ds.imaging.embeddings.extract <- function(conns, dataset_id = NULL,
                                          image_asset = "images",
                                          model = "intensity_histogram",
                                          bins = 32L,
                                          output_asset = "image_embeddings",
                                          visibility = "private",
                                          alias = NULL,
                                          handle = "img") {
  config <- .compact_list(list(
    image_asset = image_asset,
    model = model,
    bins = as.integer(bins)
  ))
  job <- .imaging_asset_job(dataset_id, label_tag = "embeddings",
    runner = "image_embeddings", config = config,
    output_asset = output_asset, asset_type = "embedding_table",
    visibility = visibility, alias = alias, handle = handle)
  .submit_imaging_job(conns, job)
}

#' @keywords internal
.imaging_asset_job <- function(dataset_id, label_tag, runner, config,
                               output_asset, asset_type,
                               visibility = "private", alias = NULL,
                               handle = "img") {
  .require_private_workflow_visibility(visibility)
  config$dataset_id <- NULL
  list(domain_method = "imagingProcessAssetWorkflowDS",
    handle = handle, dataset_id = dataset_id, runner = runner,
    config = config, output_asset = output_asset, alias = alias)
}

#' @keywords internal
.compact_list <- function(x) {
  x[!vapply(x, is.null, logical(1))]
}
