# Run mask or ROI operations

Supports `binarize`, `label_select`, `connected_components`,
`morphology`, `union`, `intersection`, `difference`, and
`resample_to_image`.

## Usage

``` r
ds.imaging.mask.operation(
  conns,
  dataset_id,
  operation,
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
  alias = NULL
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character; dataset identifier.

- operation:

  Character; mask operation.

- mask_asset:

  Character; primary mask asset.

- mask_b_asset:

  Character or NULL; secondary mask asset for pair ops.

- reference_asset:

  Character or NULL; image asset for resampling masks.

- labels:

  Integer vector or NULL; labels for `label_select`.

- threshold:

  Numeric; threshold for binarization.

- mode:

  Character; morphology mode.

- radius:

  Integer; morphology radius.

- min_voxels:

  Integer; minimum component size.

- max_components:

  Integer; max components to keep.

- output_asset:

  Character; published mask asset name.

- visibility:

  Character; job visibility label.

- alias:

  Character or NULL; optional asset alias.

## Value

A dshpc_submission.
