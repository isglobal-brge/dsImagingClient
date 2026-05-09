# Load a Published Imaging Feature Asset

Assigns a server-side feature table asset, such as a radiomics
collection, into the DataSHIELD session so standard analysis packages
can operate on it.

## Usage

``` r
ds.imaging.load_asset(
  conns,
  dataset_id,
  asset_id,
  symbol = "imaging_features",
  columns = NULL,
  include_metadata = FALSE,
  syntactic_names = FALSE
)

ds.imaging.radiomics.load_features(
  conns,
  dataset_id,
  asset_id,
  symbol = "radiomics",
  columns = NULL,
  include_metadata = FALSE,
  syntactic_names = FALSE
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character; dataset identifier.

- asset_id:

  Character; asset id or alias.

- symbol:

  Character; target server-side symbol.

- columns:

  Optional character vector of columns to keep.

- include_metadata:

  Logical; if TRUE, load feature rows joined with dataset
  metadata/clinical columns on `sample_id`.

- syntactic_names:

  Logical; if TRUE, repair server-side column names for formula-based
  DataSHIELD models.

## Value

Invisibly TRUE.
