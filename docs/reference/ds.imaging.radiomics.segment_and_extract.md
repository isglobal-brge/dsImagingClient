# Segment images then extract radiomics features

Chains segmentation and extraction into a single job. Checks for
existing masks and radiomics before recomputing.

## Usage

``` r
ds.imaging.radiomics.segment_and_extract(
  conns,
  dataset_id,
  image_asset = "images",
  segmenter,
  profile = ds.imaging.radiomics.profile.ibsi_ct_3d(),
  visibility = "private",
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

- profile:

  A radiomics profile from ds.imaging.radiomics.profile.\*().

- visibility:

  Character; job visibility label (default "private").

- symbol:

  Character or NULL; target server-side symbol for the workflow handle.
  If NULL, a temporary symbol is generated.

## Value

A domain-mediated workflow submission handle.
