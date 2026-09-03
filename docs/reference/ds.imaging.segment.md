# Segment images in a dataset

Segment images in a dataset

## Usage

``` r
ds.imaging.segment(
  conns,
  dataset_id = NULL,
  image_asset = "images",
  segmenter,
  visibility = "private",
  alias = NULL,
  symbol = NULL,
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

  Character; asset_id or alias for images.

- segmenter:

  A segmenter from ds.imaging.segmenter.\*().

- visibility:

  Compatibility argument; analytical workflows only accept `"private"`.
  Global publication is administrator-only.

- alias:

  Character or NULL; alias for the published mask.

- symbol:

  Character or NULL; target server-side symbol for the workflow handle.
  If NULL, a temporary symbol is generated.

- handle:

  Character; initialized imaging handle (default `"img"`).

## Value

A domain-mediated workflow submission handle.
