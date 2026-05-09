# Preprocess image assets

Supports resampling, z-score normalization, intensity
clamping/windowing, and float32 casting through the `image_preprocess`
runner.

## Usage

``` r
ds.imaging.preprocess(
  conns,
  dataset_id,
  image_asset = "images",
  operations = c("float32"),
  spacing = NULL,
  lower = -1000,
  upper = 1000,
  output_asset = "preprocessed_images",
  visibility = "global",
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

  Character vector; operations such as `"resample"`, `"normalize"`,
  `"clamp"`, and `"float32"`.

- spacing:

  Numeric vector or NULL; target spacing for resampling.

- lower:

  Numeric; lower clamp/window value.

- upper:

  Numeric; upper clamp/window value.

- output_asset:

  Character; published asset name.

- visibility:

  Character; job visibility label.

- alias:

  Character or NULL; optional asset alias.

## Value

A dshpc_submission.
