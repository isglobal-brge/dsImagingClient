# Create an opaque imaging feature view for dsFlower

Assigns a complete radiomics/feature asset behind a session-bound
capability. Unlike
[`ds.imaging.load_asset()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.load_asset.md),
this never places a data.frame in the workspace: dsFlower receives the
patient mapping only through dsImaging's trusted same-session resolver.

## Usage

``` r
ds.imaging.feature_view(
  conns,
  asset_id,
  symbol = "imaging_features",
  columns = NULL,
  handle = "img"
)
```

## Arguments

- conns:

  DSI connections object.

- asset_id:

  Character asset id/alias used on every server, a named list with one
  id per server, or a workflow-status result.

- symbol:

  Character; target feature-view symbol.

- columns:

  Optional public feature-column selection.

- handle:

  Character; initialized imaging handle.

## Value

Invisibly TRUE.
