# Module: Segmentation Provider Constructors

#' Use existing mask asset (no segmentation needed)
#' @param mask_asset Character; asset_id or alias of existing masks.
#' @return A segmenter spec.
#' @export
ds.imaging.segmenter.existing_mask <- function(mask_asset) {
  list(provider = "existing_mask_asset", mask_asset = mask_asset)
}

#' TotalSegmentator segmenter
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
#' @param model_name Character; registered model name.
#' @param fold Character; fold to use (default "all").
#' @return A segmenter spec.
#' @export
ds.imaging.segmenter.nnunet <- function(model_name, fold = "all") {
  list(provider = "nnunetv2_predict", model_name = model_name, fold = fold)
}

#' MONAI bundle segmenter
#' @param bundle_name Character; registered bundle name.
#' @return A segmenter spec.
#' @export
ds.imaging.segmenter.monai_bundle <- function(bundle_name) {
  stop("MONAI bundle segmentation is unavailable until an exact per-sample contract is implemented.",
       call. = FALSE)
}
