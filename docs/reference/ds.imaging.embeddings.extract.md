# Extract image embeddings

Extract image embeddings

## Usage

``` r
ds.imaging.embeddings.extract(
  conns,
  dataset_id,
  image_asset = "images",
  model = "intensity_histogram",
  bins = 32L,
  output_asset = "image_embeddings",
  visibility = "private",
  alias = NULL
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character; dataset identifier.

- image_asset:

  Character; image asset or alias.

- model:

  Character; embedding model name. The default is a deterministic
  intensity histogram baseline.

- bins:

  Integer; histogram bins for the baseline embedding.

- output_asset:

  Character; published embedding table asset name.

- visibility:

  Character; job visibility label.

- alias:

  Character or NULL; optional asset alias.

## Value

A dshpc_submission.
