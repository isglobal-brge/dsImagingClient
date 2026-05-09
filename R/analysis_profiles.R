# Module: Radiomics Profile Constructors
# Each returns a named list describing PyRadiomics settings.

#' IBSI-compliant CT 3D profile
#' @param bin_width Numeric; histogram bin width (default 25).
#' @return A radiomics profile spec.
#' @export
ds.imaging.radiomics.profile.ibsi_ct_3d <- function(bin_width = 25) {
  list(name = "ibsi_ct_3d_v1", bin_width = bin_width,
       force2D = FALSE, normalize = TRUE,
       resampled_spacing = c(1, 1, 1),
       feature_classes = c("firstorder", "glcm", "glrlm", "glszm", "gldm", "ngtdm"),
       image_types = c("Original", "LoG", "Wavelet"))
}

#' Lightweight CT first-order demo profile
#'
#' Uses Original image first-order features only. This is intended for
#' plug-and-play demos and constrained Rock containers where wavelet/LoG
#' feature families can be too memory intensive.
#'
#' @param bin_width Numeric; histogram bin width (default 25).
#' @return A radiomics profile spec.
#' @export
ds.imaging.radiomics.profile.demo_ct_firstorder <- function(bin_width = 25) {
  list(name = "demo_ct_firstorder_v1", bin_width = bin_width,
       force2D = FALSE, normalize = FALSE,
       resampled_spacing = NULL,
       feature_classes = c("firstorder"),
       image_types = c("Original"))
}

#' Aerts 4-feature CT radiomic signature profile
#'
#' Matches the public LUNG1 / Aerts-signature replication path:
#' bin width 25, no normalisation, no resampling, Original + Wavelet
#' image types, and the published firstorder/shape/GLRLM feature classes.
#'
#' @param bin_width Numeric; histogram bin width (default 25).
#' @return A radiomics profile spec.
#' @export
ds.imaging.radiomics.profile.aerts_signature <- function(bin_width = 25) {
  list(name = "aerts_signature_v1", bin_width = bin_width,
       force2D = FALSE, normalize = FALSE,
       resampled_spacing = NULL,
       feature_classes = c("firstorder", "shape", "glrlm"),
       image_types = c("Original", "Wavelet"),
       selected_features = c(
         "original_firstorder_Energy",
         "original_shape_Compactness1",
         "original_glrlm_RunLengthNonUniformity",
         "wavelet-HLH_glrlm_RunLengthNonUniformity"
       ))
}

#' IBSI-compliant MR 3D profile
#'
#' @param bin_width Numeric; histogram bin width (default 25).
#' @return A radiomics profile spec.
#' @export
ds.imaging.radiomics.profile.ibsi_mr_3d <- function(bin_width = 25) {
  list(name = "ibsi_mr_3d_v1", bin_width = bin_width,
       force2D = FALSE, normalize = TRUE,
       resampled_spacing = c(1, 1, 1),
       feature_classes = c("firstorder", "glcm", "glrlm", "glszm", "gldm"),
       image_types = c("Original", "LoG"))
}

#' Force-2D profile (for 2D slices)
#'
#' @param bin_width Numeric; histogram bin width (default 25).
#' @return A radiomics profile spec.
#' @export
ds.imaging.radiomics.profile.force2d <- function(bin_width = 25) {
  list(name = "ibsi_force2d_v1", bin_width = bin_width,
       force2D = TRUE, normalize = TRUE,
       feature_classes = c("firstorder", "glcm", "glrlm"),
       image_types = c("Original"))
}

#' Voxel-based feature map (firstorder only)
#'
#' @param bin_width Numeric; histogram bin width (default 25).
#' @param kernel_radius Numeric; voxel-neighborhood kernel radius.
#' @return A radiomics profile spec.
#' @export
ds.imaging.radiomics.profile.voxel_firstorder <- function(bin_width = 25, kernel_radius = 2) {
  list(name = "voxel_map_firstorder_v1", bin_width = bin_width,
       voxel_based = TRUE, kernel_radius = kernel_radius,
       feature_classes = c("firstorder"),
       image_types = c("Original"))
}
