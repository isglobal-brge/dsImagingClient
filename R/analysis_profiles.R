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

#' Historical or published Aerts four-feature CT profile
#'
#' The default \code{v1} preserves the historical Aerts-inspired profile:
#' Energy, Compactness1, and original/wavelet-HLH RunLengthNonUniformity.
#' Select \code{version = "v2"} for the published feature selection: Energy,
#' Compactness2 (sphericity cubed), and original/wavelet-HLH
#' GrayLevelNonUniformity. Both retain bin width 25, no normalisation or
#' resampling, and the same coif1 wavelet settings. This specifies features,
#' not a fitted prognostic model or a reproduction of historical results.
#'
#' @references Aerts et al. (2014), doi:10.1038/ncomms5006, Supplementary
#'   Figure 1 and Methods feature 16 (Compactness2);
#'   Shi et al. (2019), doi:10.1038/s41597-019-0241-0.
#'
#' @param bin_width Numeric; histogram bin width (default 25).
#' @param version Character; \code{"v1"} (historical default) or \code{"v2"}.
#' @return A radiomics profile spec.
#' @export
ds.imaging.radiomics.profile.aerts_signature <- function(bin_width = 25,
                                                       version = c("v1", "v2")) {
  version <- match.arg(version)
  compactness <- if (identical(version, "v1")) "Compactness1" else "Compactness2"
  nonuniformity <- if (identical(version, "v1")) {
    "RunLengthNonUniformity"
  } else "GrayLevelNonUniformity"
  list(name = paste0("aerts_signature_", version), bin_width = bin_width,
       force2D = FALSE, normalize = FALSE,
       resampled_spacing = NULL,
       feature_classes = c("firstorder", "shape", "glrlm"),
       image_types = c("Original", "Wavelet"),
       selected_features = c(
         "original_firstorder_Energy",
         paste0("original_shape_", compactness),
         paste0("original_glrlm_", nonuniformity),
         paste0("wavelet-HLH_glrlm_", nonuniformity)
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
