# Lightweight CT lung threshold segmenter

Creates a deterministic whole-lung mask from CT intensities using
SimpleITK connected components. This is intended as a fast,
dependency-light demo/QC segmenter; use model-based segmenters for
production organ segmentation.

## Usage

``` r
ds.segmenter.ct_lung_threshold(
  threshold = -320,
  max_components = 2L,
  min_voxels = 1000L
)

ds.imaging.segmenter.ct_lung_threshold(
  threshold = -320,
  max_components = 2L,
  min_voxels = 1000L
)
```

## Arguments

- threshold:

  Numeric HU upper threshold for candidate lung air.

- max_components:

  Integer maximum internal air components to keep.

- min_voxels:

  Integer minimum component size in voxels.

## Value

A segmenter spec.
