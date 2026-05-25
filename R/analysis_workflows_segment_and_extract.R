# Module: Segment + Extract Chained Workflow

#' Segment images then extract radiomics features
#'
#' Chains segmentation and extraction into a single job.
#' Checks for existing masks and radiomics before recomputing.
#'
#' @param conns DSI connections object.
#' @param dataset_id Character; dataset identifier.
#' @param image_asset Character; asset_id or alias for images.
#' @param segmenter A segmenter from ds.imaging.segmenter.*().
#' @param profile A radiomics profile from ds.imaging.radiomics.profile.*().
#' @param visibility Character; job visibility label (default "global").
#' @return A dshpc_submission.
#' @export
ds.imaging.radiomics.segment_and_extract <- function(conns, dataset_id,
                                               image_asset = "images",
                                               segmenter,
                                               profile = ds.imaging.radiomics.profile.ibsi_ct_3d(),
                                               visibility = "global") {
  # Check if segmentation already exists
  seg_hash <- .compute_derivation_hash(
    dataset_id = dataset_id,
    image_asset = image_asset,
    provider = segmenter$provider,
    task = segmenter$task %||% "default",
    model_name = segmenter$model_name %||% segmenter$bundle_name %||% "default"
  )

  # Check if full pipeline (seg+extract) already exists
  full_hash <- .compute_derivation_hash(
    dataset_id = dataset_id,
    image_asset = image_asset,
    segmenter = segmenter,
    profile_name = profile$name,
    bin_width = profile$bin_width
  )

  existing <- ds.imaging.check_exists(conns, dataset_id,
    derivation_hash = full_hash)
  first_srv <- names(existing)[1]
  if (!is.null(existing[[first_srv]]) && isTRUE(existing[[first_srv]]$exists)) {
    message("Segment+extract already computed: ", existing[[first_srv]]$asset_id)
    return(list(deduplicated = TRUE, asset_id = existing[[first_srv]]$asset_id))
  }

  # Build runner name for segmentation
  seg_runner <- switch(segmenter$provider,
    existing_mask_asset = NULL,
    totalsegmentator = "totalsegmentator_infer",
    totalsegmentator_infer = "totalsegmentator_infer",
    lungmask = "lungmask_infer",
    lungmask_infer = "lungmask_infer",
    ct_lung_threshold = "ct_lung_threshold",
    nnunetv2_predict = "nnunetv2_predict",
    monai_bundle_infer = "monai_bundle_infer",
    stop("Unknown provider: ", segmenter$provider, call. = FALSE))

  mask_asset_for_extract <- segmenter$mask_asset %||% "masks"
  if (!is.null(seg_runner)) {
    existing_seg <- ds.imaging.check_exists(conns, dataset_id,
      derivation_hash = seg_hash)
    seg_srv <- names(existing_seg)[1]
    if (!is.null(existing_seg[[seg_srv]]) &&
        isTRUE(existing_seg[[seg_srv]]$exists)) {
      mask_asset_for_extract <- existing_seg[[seg_srv]]$asset_id
      message("Reusing existing segmentation: ", mask_asset_for_extract)
      seg_runner <- NULL
    }
  }

  # Build steps
  steps <- list(dsHPCClient::ds_step_resolve_dataset(dataset_id))

  # Segmentation step (if not using existing masks)
  if (!is.null(seg_runner)) {
    seg_config <- segmenter
    seg_config$image_asset <- image_asset
    mask_publish_step <- dsHPCClient::ds_step_publish_asset(dataset_id, "masks",
      asset_type = "mask_root", publish_kind = "imaging_asset")
    mask_publish_step$runner <- seg_runner
    mask_publish_step$config <- seg_config
    mask_publish_step$derivation_hash <- seg_hash
    steps <- c(steps, list(
      dsHPCClient::ds_step_run_artifact(seg_runner, config = seg_config),
      mask_publish_step
    ))
  }

  # Extraction step
  extract_config <- c(profile, list(
    mask_asset = mask_asset_for_extract,
    image_asset = image_asset,
    settings_file = profile$name
  ))
  radiomics_publish_step <- dsHPCClient::ds_step_publish_asset(dataset_id,
    "radiomics", asset_type = "feature_table",
    publish_kind = "imaging_radiomics_asset")
  radiomics_publish_step$runner <- "pyradiomics_extract"
  radiomics_publish_step$config <- extract_config
  radiomics_publish_step$derivation_hash <- full_hash

  extract_step <- dsHPCClient::ds_step_run_artifact("pyradiomics_extract",
    config = extract_config)
  if (!is.null(seg_runner)) {
    extract_step$inputs <- list(2L)
  }
  steps <- c(steps, list(
    extract_step,
    radiomics_publish_step,
    dsHPCClient::ds_step_safe_summary()
  ))

  job <- dsHPCClient::ds_job(
    label = "dsImaging",
    tags = c("segment_and_extract", dataset_id, segmenter$provider, profile$name),
    visibility = visibility,
    steps = steps
  )

  .submit_imaging_job(conns, job)
}
