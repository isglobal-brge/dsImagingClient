# Legacy unrestricted asset lineage query

Shows which parent assets this was derived from (e.g. radiomics table
derived from image_root + mask_root).

## Usage

``` r
ds.imaging.lineage(conns, asset_id)
```

## Arguments

- conns:

  DSI connections object.

- asset_id:

  Character; the asset identifier.

## Value

This function always errors with migration guidance.
