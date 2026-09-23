# Module: Segmentation Provider Constructors

#' Use existing mask asset (no segmentation needed)
#' @param mask_asset Character; asset_id or alias of existing masks.
#' @return A segmenter spec.
#' @export
ds.imaging.segmenter.existing_mask <- function(mask_asset) {
  list(provider = "existing_mask_asset", mask_asset = mask_asset)
}

#' TotalSegmentator segmenter
#'
#' Requires an administrator-registered, verified bundle for the selected task,
#' including its auxiliary models and requested resolution. No weights download
#' during inference.
#' @param task Character; segmentation task (default "total").
#' @param fast Logical; use fast mode (default FALSE).
#' @param roi_subset Character vector or NULL; specific ROIs.
#' @return A segmenter spec.
#' @export
ds.imaging.segmenter.totalsegmentator <- function(task = "total", fast = FALSE,
                                            roi_subset = NULL) {
  list(provider = "totalsegmentator", task = task, fast = fast,
       roi_subset = roi_subset)
}

#' LungMask segmenter (lung/lobe specific)
#'
#' Requires an administrator-registered, verified bundle for the selected model.
#' Fused models also require their fill-model weights. No weights download
#' during inference.
#' @param model Character; "R231", "LTRCLobes", "LTRCLobes_R231", "R231CovidWeb".
#' @return A segmenter spec.
#' @export
ds.imaging.segmenter.lungmask <- function(model = "R231") {
  list(provider = "lungmask_infer", model_name = model)
}

#' Lightweight CT lung threshold segmenter
#'
#' Creates a deterministic whole-lung mask from CT intensities using
#' SimpleITK connected components. This is intended as a fast,
#' dependency-light demo/QC segmenter; use model-based segmenters for
#' production organ segmentation.
#'
#' @param threshold Numeric HU upper threshold for candidate lung air.
#' @param max_components Integer maximum internal air components to keep.
#' @param min_voxels Integer minimum component size in voxels.
#' @return A segmenter spec.
#' @export
ds.imaging.segmenter.ct_lung_threshold <- function(threshold = -320,
                                           max_components = 2L,
                                           min_voxels = 1000L) {
  list(provider = "ct_lung_threshold",
       threshold = threshold,
       max_components = as.integer(max_components),
       min_voxels = as.integer(min_voxels))
}

#' nnU-Net v2 segmenter
#'
#' Resolves an administrator-registered, verified model bundle on each server.
#' Its selected fold and checkpoint must already be present.
#' @param model_name Character; registered nnU-Net bundle task identifier.
#' @param fold Character; fold to use (default "all").
#' @return A segmenter spec.
#' @export
ds.imaging.segmenter.nnunet <- function(model_name, fold = "all") {
  list(provider = "nnunetv2_predict", model_name = model_name, fold = fold)
}

#' MONAI bundle segmenter
#'
#' Uses an administrator-registered, digest-verified bundle, including its
#' inference configuration and all weights. Inference is offline.
#' Each admitted sample must produce
#' exactly one mask with matching image geometry; mask bodies stay server-side.
#' @param bundle_name Character; registered MONAI bundle task identifier.
#' @return A segmenter spec.
#' @export
ds.imaging.segmenter.monai_bundle <- function(bundle_name) {
  list(provider = "monai_bundle_infer", bundle_name = bundle_name)
}
