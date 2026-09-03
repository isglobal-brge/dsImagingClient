# Extract radiomics features from a dataset

Checks for existing identical derivation first (deduplication). If not
found, submits a dsHPC job.

## Usage

``` r
ds.imaging.radiomics.extract(
  conns,
  dataset_id = NULL,
  image_asset = "images",
  mask_asset,
  profile = ds.imaging.radiomics.profile.ibsi_ct_3d(),
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

  Character; asset_id or alias for images (default "images").

- mask_asset:

  Character; asset_id or alias for masks.

- profile:

  A radiomics profile from ds.imaging.radiomics.profile.\*().

- visibility:

  Compatibility argument; analytical workflows only accept `"private"`.
  Global publication is administrator-only.

- alias:

  Character or NULL; alias for the published feature table.

- symbol:

  Character or NULL; target server-side symbol for the workflow handle.
  If NULL, a temporary symbol is generated.

- handle:

  Character; initialized imaging handle (default `"img"`).

## Value

A domain-mediated workflow submission handle.
