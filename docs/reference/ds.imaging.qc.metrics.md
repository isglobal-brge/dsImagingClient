# Compute image and mask QC metrics

Produces a server-side CSV/JSON QC output with image
size/spacing/intensity summaries and optional mask volume/intensity
summaries.

## Usage

``` r
ds.imaging.qc.metrics(
  conns,
  dataset_id = NULL,
  image_asset = "images",
  mask_asset = NULL,
  output_asset = "imaging_qc",
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

  Character; image asset to summarize.

- mask_asset:

  Character or NULL; optional mask asset.

- output_asset:

  Character; published QC asset name.

- visibility:

  Character; job visibility label.

- alias:

  Character or NULL; optional asset alias.

- handle:

  Character; initialized imaging handle (default `"img"`).

## Value

A domain-mediated workflow submission handle.
