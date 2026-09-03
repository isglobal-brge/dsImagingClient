# Legacy client-side derivation lookup

Before submitting a job to extract radiomics or preprocess images, check
if an identical derivation (same parameters, model, version) already
exists. If it does, skip recomputation and use the existing asset.

## Usage

``` r
ds.imaging.check_exists(conns, dataset_id, ...)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character; the dataset identifier.

- ...:

  Named parameters to hash (model, version, settings, mask_asset, etc.)

## Value

This function always errors with migration guidance.
