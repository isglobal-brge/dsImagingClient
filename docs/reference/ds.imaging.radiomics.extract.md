# Extract radiomics features from a dataset

Checks for existing identical derivation first (deduplication). If not
found, submits a dsHPC job.

## Usage

``` r
ds.imaging.radiomics.extract(
  conns,
  dataset_id,
  image_asset = "images",
  mask_asset,
  profile = ds.imaging.radiomics.profile.ibsi_ct_3d(),
  visibility = "private",
  alias = NULL,
  symbol = NULL
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character; the dataset identifier.

- image_asset:

  Character; asset_id or alias for images (default "images").

- mask_asset:

  Character; asset_id or alias for masks.

- profile:

  A radiomics profile from ds.imaging.radiomics.profile.\*().

- visibility:

  Character; job visibility label (default "private").

- alias:

  Character or NULL; alias for the published feature table.

- symbol:

  Character or NULL; target server-side symbol for the workflow handle.
  If NULL, a temporary symbol is generated.

## Value

A domain-mediated workflow submission handle.
