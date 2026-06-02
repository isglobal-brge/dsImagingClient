# Run spatial image operations

Run spatial image operations

## Usage

``` r
ds.imaging.spatial.process(
  conns,
  dataset_id,
  image_asset = "images",
  operations = c("resample"),
  mask_asset = NULL,
  reference_asset = NULL,
  spacing = NULL,
  crop_size = NULL,
  output_asset = "spatial_images",
  visibility = "private",
  alias = NULL
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character; dataset identifier.

- image_asset:

  Character; source image asset.

- operations:

  Character vector; `resample`, `crop_to_mask`, `center_crop`,
  `n4_bias`, or `register_rigid`.

- mask_asset:

  Character or NULL; mask asset for `crop_to_mask`.

- reference_asset:

  Character or NULL; reference asset for registration.

- spacing:

  Numeric vector or NULL; target spacing for `resample`.

- crop_size:

  Integer vector or NULL; center crop size.

- output_asset:

  Character; published image asset name.

- visibility:

  Character; job visibility label.

- alias:

  Character or NULL; optional asset alias.

## Value

A dshpc_submission.
