# Module: Compatibility Aliases
#
# dsImagingClient is the canonical client. The ds.radiomics.* and
# ds.segmenter.* wrappers keep existing demos usable while new code uses
# ds.imaging.* names.

#' @rdname ds.imaging.radiomics.profile.ibsi_ct_3d
#' @export
ds.radiomics.profile.ibsi_ct_3d <- function(bin_width = 25) {
  ds.imaging.radiomics.profile.ibsi_ct_3d(bin_width)
}

#' @rdname ds.imaging.radiomics.profile.demo_ct_firstorder
#' @export
ds.radiomics.profile.demo_ct_firstorder <- function(bin_width = 25) {
  ds.imaging.radiomics.profile.demo_ct_firstorder(bin_width)
}

#' @rdname ds.imaging.radiomics.profile.aerts_signature
#' @export
ds.radiomics.profile.aerts_signature <- function(bin_width = 25) {
  ds.imaging.radiomics.profile.aerts_signature(bin_width)
}

#' @rdname ds.imaging.radiomics.profile.ibsi_mr_3d
#' @export
ds.radiomics.profile.ibsi_mr_3d <- function(bin_width = 25) {
  ds.imaging.radiomics.profile.ibsi_mr_3d(bin_width)
}

#' @rdname ds.imaging.radiomics.profile.force2d
#' @export
ds.radiomics.profile.force2d <- function(bin_width = 25) {
  ds.imaging.radiomics.profile.force2d(bin_width)
}

#' @rdname ds.imaging.radiomics.profile.voxel_firstorder
#' @export
ds.radiomics.profile.voxel_firstorder <- function(bin_width = 25,
                                                  kernel_radius = 2) {
  ds.imaging.radiomics.profile.voxel_firstorder(bin_width, kernel_radius)
}

#' @rdname ds.imaging.segmenter.existing_mask
#' @export
ds.segmenter.existing_mask <- function(mask_asset) {
  ds.imaging.segmenter.existing_mask(mask_asset)
}

#' @rdname ds.imaging.segmenter.totalsegmentator
#' @export
ds.segmenter.totalsegmentator <- function(task = "total", fast = FALSE,
                                          roi_subset = NULL) {
  ds.imaging.segmenter.totalsegmentator(task, fast, roi_subset)
}

#' @rdname ds.imaging.segmenter.lungmask
#' @export
ds.segmenter.lungmask <- function(model = "R231") {
  ds.imaging.segmenter.lungmask(model)
}

#' @rdname ds.imaging.segmenter.ct_lung_threshold
#' @export
ds.segmenter.ct_lung_threshold <- function(threshold = -320,
                                           max_components = 2L,
                                           min_voxels = 1000L) {
  ds.imaging.segmenter.ct_lung_threshold(threshold, max_components,
    min_voxels)
}

#' @rdname ds.imaging.segmenter.nnunet
#' @export
ds.segmenter.nnunet <- function(model_name, fold = "all") {
  ds.imaging.segmenter.nnunet(model_name, fold)
}

#' @rdname ds.imaging.segmenter.monai_bundle
#' @export
ds.segmenter.monai_bundle <- function(bundle_name) {
  ds.imaging.segmenter.monai_bundle(bundle_name)
}

#' @rdname ds.imaging.segment
#' @export
ds.radiomics.segment <- function(conns, dataset_id, image_asset = "images",
                                 segmenter, visibility = "global",
                                 alias = NULL) {
  ds.imaging.segment(conns, dataset_id, image_asset, segmenter, visibility,
    alias)
}

#' @rdname ds.imaging.radiomics.extract
#' @export
ds.radiomics.extract <- function(conns, dataset_id, image_asset = "images",
                                 mask_asset,
                                 profile = ds.radiomics.profile.ibsi_ct_3d(),
                                 visibility = "global", alias = NULL) {
  ds.imaging.radiomics.extract(conns, dataset_id, image_asset, mask_asset,
    profile, visibility, alias)
}

#' @rdname ds.imaging.radiomics.segment_and_extract
#' @export
ds.radiomics.segment_and_extract <- function(conns, dataset_id,
                                             image_asset = "images",
                                             segmenter,
                                             profile = ds.radiomics.profile.ibsi_ct_3d(),
                                             visibility = "global") {
  ds.imaging.radiomics.segment_and_extract(conns, dataset_id, image_asset,
    segmenter, profile, visibility)
}

#' @rdname ds.imaging.radiomics.process_collection
#' @export
ds.radiomics.process_collection <- function(conns, dataset_id, segmenter,
                                            profile = ds.radiomics.profile.ibsi_ct_3d(),
                                            batch_size = 10L,
                                            poll_interval = 15,
                                            timeout = 14400,
                                            allow_partial = FALSE,
                                            visibility = "global") {
  ds.imaging.radiomics.process_collection(conns, dataset_id, segmenter,
    profile, batch_size, poll_interval, timeout, allow_partial, visibility)
}

#' @rdname ds.imaging.radiomics.collection_status
#' @export
ds.radiomics.collection_status <- function(conns, generation_id) {
  ds.imaging.radiomics.collection_status(conns, generation_id)
}

#' @rdname ds.imaging.radiomics.collection_recover
#' @export
ds.radiomics.collection_recover <- function(conns, generation_id) {
  ds.imaging.radiomics.collection_recover(conns, generation_id)
}

#' @rdname ds.imaging.radiomics.collection_cancel
#' @export
ds.radiomics.collection_cancel <- function(conns, generation_id, admin_key,
                                           reason = "Cancelled by admin") {
  ds.imaging.radiomics.collection_cancel(conns, generation_id, admin_key,
    reason)
}

#' @rdname ds.imaging.radiomics.collection_publish
#' @export
ds.radiomics.collection_publish <- function(conns, generation_id, dataset_id,
                                            allow_partial = FALSE) {
  ds.imaging.radiomics.collection_publish(conns, generation_id, dataset_id,
    allow_partial)
}

#' @rdname ds.imaging.install_model
#' @export
ds.radiomics.install_model <- function(conns, admin_key, provider, task) {
  ds.imaging.install_model(conns, admin_key, provider, task)
}

#' @rdname ds.imaging.models
#' @export
ds.radiomics.models <- function(conns) {
  ds.imaging.models(conns)
}

#' @rdname ds.imaging.jobs
#' @export
ds.radiomics.list <- function(conns) {
  ds.imaging.jobs(conns)
}

#' @rdname ds.imaging.radiomics.features
#' @export
ds.radiomics.features <- function(conns, dataset_id) {
  ds.imaging.radiomics.features(conns, dataset_id)
}

#' @rdname ds.imaging.masks
#' @export
ds.radiomics.masks <- function(conns, dataset_id) {
  ds.imaging.masks(conns, dataset_id)
}

#' @rdname ds.imaging.capabilities
#' @export
ds.radiomics.capabilities <- function(conns) {
  ds.imaging.capabilities(conns)
}

#' @rdname ds.imaging.summary
#' @export
ds.radiomics.summary <- function(conns) {
  ds.imaging.summary(conns)
}
