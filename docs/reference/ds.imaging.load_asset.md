# Load a Published Imaging Feature Asset

Assigns a server-side feature table asset, such as a radiomics
collection, into the DataSHIELD session so standard analysis packages
can operate on it.

## Usage

``` r
ds.imaging.load_asset(
  conns,
  dataset_id = NULL,
  asset_id,
  symbol = "imaging_features",
  columns = NULL,
  include_metadata = FALSE,
  syntactic_names = FALSE,
  handle = "img"
)

ds.imaging.radiomics.load_features(
  conns,
  dataset_id = NULL,
  asset_id,
  symbol = "radiomics",
  columns = NULL,
  include_metadata = FALSE,
  syntactic_names = FALSE,
  handle = "img"
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character or NULL; retained for source compatibility and ignored. The
  dataset is resolved from `handle`.

- asset_id:

  Character asset id/alias used on every server, a named list with one
  id per server, or the result of
  [`ds.imaging.workflow.status()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.workflow.status.md).

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

- handle:

  Character; initialized imaging handle (default `"img"`).

## Value

Invisibly TRUE.

## Examples

``` r
# \donttest{
# conns <- DSI::datashield.login(...)  # live DataSHIELD session
ds.imaging.radiomics.load_features(conns,
  asset_id = "asset_20260831_134344_b7b9f89e", symbol = "radiomics",
  handle = "img")
#> Error: object 'conns' not found
# }
```
