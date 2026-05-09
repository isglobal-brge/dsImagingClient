# Publish a completed collection generation

Call this after a fire-and-forget run completes to create the
collection-level asset.

## Usage

``` r
ds.radiomics.collection_publish(
  conns,
  generation_id,
  dataset_id,
  allow_partial = FALSE
)

ds.imaging.radiomics.collection_publish(
  conns,
  generation_id,
  dataset_id = NULL,
  allow_partial = FALSE
)
```

## Arguments

- conns:

  DSI connections object.

- generation_id:

  Character; the generation_id.

- dataset_id:

  Character; the dataset.

- allow_partial:

  Logical; publish even with some failures.

## Value

Named list with asset_id and summary.
