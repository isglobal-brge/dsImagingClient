# Get full details of a specific asset

Returns metadata, provenance (model, version, parameters), lineage
(parent assets), and filesystem path.

## Usage

``` r
ds.imaging.asset(conns, asset_id, dataset_id = NULL)
```

## Arguments

- conns:

  DSI connections object.

- asset_id:

  Character; asset_id or alias name.

- dataset_id:

  Character or NULL; required when using an alias.

## Value

Named list of per-server asset details.
