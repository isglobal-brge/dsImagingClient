# List derived assets for an initialized imaging handle

Shows all registered assets (masks, radiomics tables, embeddings, etc.)
with their kind, description, derivation hash, and provenance summary.

## Usage

``` r
ds.imaging.catalog(conns, dataset_id = NULL, kind = NULL, handle = "img")
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character or NULL; retained for source compatibility and ignored. The
  dataset is resolved from `handle`.

- kind:

  Character or NULL; filter by kind (e.g. "feature_table", "mask_root",
  "embedding_table").

- handle:

  Character; initialized imaging handle (default `"img"`).

## Value

Named list of per-server data.frames.

## Examples

``` r
# \donttest{
# conns <- DSI::datashield.login(...)  # live DataSHIELD session
cat_res <- ds.imaging.catalog(conns, handle = "img")
#> Error: object 'conns' not found
cat_res$site1[, c("asset_id", "kind", "created_at")]
#> Error: object 'cat_res' not found
ds.imaging.catalog(conns, kind = "radiomics_collection", handle = "img")
#> Error: object 'conns' not found
# }
```
