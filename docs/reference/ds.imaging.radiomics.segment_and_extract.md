# Segment images then extract radiomics features

Chains segmentation and extraction into a single job. Checks for
existing masks and radiomics before recomputing.

## Usage

``` r
ds.imaging.radiomics.segment_and_extract(
  conns,
  dataset_id = NULL,
  image_asset = "images",
  segmenter,
  profile = ds.imaging.radiomics.profile.ibsi_ct_3d(),
  visibility = "private",
  batch_size = 10L,
  poll_interval = 15,
  timeout = 14400,
  handle = "img",
  symbol = NULL
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

- profile:

  A radiomics profile from ds.imaging.radiomics.profile.\*().

- visibility:

  Compatibility argument; analytical workflows only accept `"private"`.
  Global publication is administrator-only.

- batch_size:

  Retained for source compatibility; the dedicated chained workflow is
  one server-owned job and does not accept client-side batches.

- poll_interval:

  Numeric; seconds between status checks.

- timeout:

  Numeric; max seconds to wait. Set to 0 for fire-and-forget.

- handle:

  Character; initialized imaging handle (default `"img"`).

- symbol:

  Character or NULL; target server-side workflow symbol.

## Value

A workflow submission when `timeout = 0`; otherwise its final
disclosure-controlled status, or a timeout response.
