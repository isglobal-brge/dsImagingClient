# Segment images then extract radiomics features

Chains segmentation and extraction into a single job. Checks for
existing masks and radiomics before recomputing.

## Usage

``` r
ds.radiomics.segment_and_extract(
  conns,
  dataset_id,
  image_asset = "images",
  segmenter,
  profile = ds.radiomics.profile.ibsi_ct_3d(),
  visibility = "global"
)

ds.imaging.radiomics.segment_and_extract(
  conns,
  dataset_id,
  image_asset = "images",
  segmenter,
  profile = ds.imaging.radiomics.profile.ibsi_ct_3d(),
  visibility = "global"
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

  Character; job visibility label (default "global").

## Value

A dshpc_submission.
