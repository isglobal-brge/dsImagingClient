# Segment images in a dataset

Segment images in a dataset

## Usage

``` r
ds.imaging.segment(
  conns,
  dataset_id,
  image_asset = "images",
  segmenter,
  visibility = "private",
  alias = NULL,
  symbol = NULL
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

  Character; job visibility label (default "private").

- alias:

  Character or NULL; alias for the published mask.

- symbol:

  Character or NULL; target server-side symbol for the workflow handle.
  If NULL, a temporary symbol is generated.

## Value

A domain-mediated workflow submission handle.
