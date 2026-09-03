# Legacy full asset detail query

Full asset detail queries are retired because they exposed storage paths
and unrestricted provenance. Use the handle-scoped catalog instead.

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

This function always errors with migration guidance.
