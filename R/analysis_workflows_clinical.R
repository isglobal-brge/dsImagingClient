# Module: Clinical Imaging Workflows
# Generic imaging jobs beyond segmentation/radiomics.

#' Convert DICOM series to NIfTI images
#'
#' Submits a dsJobs-backed conversion job. The runner uses `dcm2niix` when
#' available and falls back to SimpleITK series reading.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character; dataset identifier.
#' @param dicom_asset Character; manifest asset containing DICOM series.
#' @param output_asset Character; name for the published NIfTI image asset.
#' @param converter Character; `"auto"`, `"dcm2niix"`, or `"simpleitk"`.
#' @param visibility Character; job visibility label.
#' @param alias Character or NULL; optional asset alias.
#' @return A dsjobs_submission.
#' @export
ds.imaging.dicom.convert <- function(conns, dataset_id, dicom_asset = "dicom",
                                     output_asset = "nifti_images",
                                     converter = "auto",
                                     visibility = "global",
                                     alias = NULL) {
  config <- .compact_list(list(
    dataset_id = dataset_id,
    dicom_asset = dicom_asset,
    converter = converter
  ))
  job <- .imaging_asset_job(dataset_id, label_tag = "dicom_convert",
    runner = "dicom_convert", config = config, output_asset = output_asset,
    asset_type = "image_root", visibility = visibility, alias = alias)
  dsJobsClient::ds.jobs.submit(conns, job)
}

#' Preprocess image assets
#'
#' Supports resampling, z-score normalization, intensity clamping/windowing, and
#' float32 casting through the `image_preprocess` runner.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character; dataset identifier.
#' @param image_asset Character; source image asset.
#' @param operations Character vector; operations such as `"resample"`,
#'   `"normalize"`, `"clamp"`, and `"float32"`.
#' @param spacing Numeric vector or NULL; target spacing for resampling.
#' @param lower Numeric; lower clamp/window value.
#' @param upper Numeric; upper clamp/window value.
#' @param output_asset Character; published asset name.
#' @param visibility Character; job visibility label.
#' @param alias Character or NULL; optional asset alias.
#' @return A dsjobs_submission.
#' @export
ds.imaging.preprocess <- function(conns, dataset_id, image_asset = "images",
                                  operations = c("float32"),
                                  spacing = NULL,
                                  lower = -1000,
                                  upper = 1000,
                                  output_asset = "preprocessed_images",
                                  visibility = "global",
                                  alias = NULL) {
  config <- .compact_list(list(
    dataset_id = dataset_id,
    image_asset = image_asset,
    operations = paste(operations, collapse = ","),
    spacing = if (!is.null(spacing)) paste(spacing, collapse = ",") else NULL,
    lower = lower,
    upper = upper
  ))
  job <- .imaging_asset_job(dataset_id, label_tag = "preprocess",
    runner = "image_preprocess", config = config, output_asset = output_asset,
    asset_type = "image_root", visibility = visibility, alias = alias)
  dsJobsClient::ds.jobs.submit(conns, job)
}

#' Run mask or ROI operations
#'
#' Supports `binarize`, `label_select`, `connected_components`, `morphology`,
#' `union`, `intersection`, `difference`, and `resample_to_image`.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character; dataset identifier.
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
#' @return A dsjobs_submission.
#' @export
ds.imaging.mask.operation <- function(conns, dataset_id, operation,
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
                                      visibility = "global",
                                      alias = NULL) {
  config <- .compact_list(list(
    dataset_id = dataset_id,
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
    asset_type = "mask_root", visibility = visibility, alias = alias)
  dsJobsClient::ds.jobs.submit(conns, job)
}

#' Compute image and mask QC metrics
#'
#' Produces a server-side CSV/JSON QC output with image size/spacing/intensity
#' summaries and optional mask volume/intensity summaries.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character; dataset identifier.
#' @param image_asset Character; image asset to summarize.
#' @param mask_asset Character or NULL; optional mask asset.
#' @param output_asset Character; published QC asset name.
#' @param visibility Character; job visibility label.
#' @param alias Character or NULL; optional asset alias.
#' @return A dsjobs_submission.
#' @export
ds.imaging.qc.metrics <- function(conns, dataset_id, image_asset = "images",
                                  mask_asset = NULL,
                                  output_asset = "imaging_qc",
                                  visibility = "global",
                                  alias = NULL) {
  config <- .compact_list(list(
    dataset_id = dataset_id,
    image_asset = image_asset,
    mask_asset = mask_asset
  ))
  job <- .imaging_asset_job(dataset_id, label_tag = "qc_metrics",
    runner = "imaging_qc_metrics", config = config,
    output_asset = output_asset, asset_type = "qc_table",
    visibility = visibility, alias = alias)
  dsJobsClient::ds.jobs.submit(conns, job)
}

#' @keywords internal
.imaging_asset_job <- function(dataset_id, label_tag, runner, config,
                               output_asset, asset_type,
                               visibility = "global", alias = NULL) {
  publish_step <- dsJobsClient::ds_step_publish_asset(dataset_id, output_asset,
    asset_type = asset_type, publish_kind = "imaging_asset")
  publish_step$alias <- alias

  dsJobsClient::ds_job(
    label = "dsImaging",
    tags = c(label_tag, dataset_id),
    visibility = visibility,
    steps = list(
      dsJobsClient::ds_step_resolve_dataset(dataset_id),
      dsJobsClient::ds_step_run_artifact(runner, config = config),
      publish_step,
      dsJobsClient::ds_step_safe_summary()
    )
  )
}

#' @keywords internal
.compact_list <- function(x) {
  x[!vapply(x, is.null, logical(1))]
}
