# Segment images in a dataset

Segment images in a dataset

## Usage

``` r
ds.radiomics.segment(
  conns,
  dataset_id,
  image_asset = "images",
  segmenter,
  visibility = "global",
  alias = NULL
)

ds.imaging.segment(
  conns,
  dataset_id,
  image_asset = "images",
  segmenter,
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

  Character; asset_id or alias for images.

- segmenter:

  A segmenter from ds.imaging.segmenter.\*().

- visibility:

  Character; job visibility label (default "global").

- alias:

  Character or NULL; alias for the published mask.

## Value

A dshpc_submission or existing asset_id.
