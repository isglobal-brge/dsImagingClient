# Generate non-disclosive QC thumbnails and overlays

Generate non-disclosive QC thumbnails and overlays

## Usage

``` r
ds.imaging.qc.visuals(
  conns,
  dataset_id = NULL,
  image_asset = "images",
  mask_asset = NULL,
  max_size = 192L,
  max_images = 24L,
  anonymize_names = TRUE,
  output_asset = "qc_visuals",
  visibility = "private",
  alias = NULL,
  handle = "img"
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character or NULL; optional dataset identifier. The server derives it
  from `handle` and verifies any supplied value.

- image_asset:

  Character; image asset or alias.

- mask_asset:

  Character or NULL; optional mask asset.

- max_size:

  Integer; maximum PNG side length.

- max_images:

  Deprecated and ignored. The complete admitted collection is processed;
  arbitrary subsets are not supported.

- anonymize_names:

  Logical; must remain TRUE. Output names are always pseudonymized
  server-side.

- output_asset:

  Character; published QC visual asset name.

- visibility:

  Character; job visibility label.

- alias:

  Character or NULL; optional asset alias.

- handle:

  Character; initialized imaging handle (default `"img"`).

## Value

A domain-mediated workflow submission handle.
