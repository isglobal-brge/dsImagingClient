# Generate non-disclosive QC thumbnails and overlays

Generate non-disclosive QC thumbnails and overlays

## Usage

``` r
ds.imaging.qc.visuals(
  conns,
  dataset_id,
  image_asset = "images",
  mask_asset = NULL,
  max_size = 192L,
  max_images = 24L,
  anonymize_names = TRUE,
  output_asset = "qc_visuals",
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

  Character; image asset or alias.

- mask_asset:

  Character or NULL; optional mask asset.

- max_size:

  Integer; maximum PNG side length.

- max_images:

  Integer; maximum thumbnails per site.

- anonymize_names:

  Logical; hash case names in generated filenames.

- output_asset:

  Character; published QC visual asset name.

- visibility:

  Character; job visibility label.

- alias:

  Character or NULL; optional asset alias.

## Value

A dshpc_submission.
