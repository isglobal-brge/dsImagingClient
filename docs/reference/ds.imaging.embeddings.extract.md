# Extract image embeddings

Extract image embeddings

## Usage

``` r
ds.imaging.embeddings.extract(
  conns,
  dataset_id = NULL,
  image_asset = "images",
  model = "intensity_histogram",
  bins = 32L,
  output_asset = "image_embeddings",
  visibility = "private",
  alias = NULL,
  handle = "img"
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character or NULL; optional dataset identifier. The server derives it
  from `handle` and verifies any supplied value.

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

- handle:

  Character; initialized imaging handle (default `"img"`).

## Value

A domain-mediated workflow submission handle.
