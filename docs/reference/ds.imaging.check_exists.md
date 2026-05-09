# Check if a derivation already exists (deduplication)

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

Named list of per-server results with \$exists and \$asset_id.
