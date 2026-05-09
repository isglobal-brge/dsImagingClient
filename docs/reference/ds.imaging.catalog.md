# List derived assets for a dataset

Shows all registered assets (masks, radiomics tables, embeddings, etc.)
with their kind, description, derivation hash, and provenance summary.

## Usage

``` r
ds.imaging.catalog(conns, dataset_id, kind = NULL)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character; the dataset identifier.

- kind:

  Character or NULL; filter by kind (e.g. "feature_table", "mask_root",
  "embedding_table").

## Value

Named list of per-server data.frames.
