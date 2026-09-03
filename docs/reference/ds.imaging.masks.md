# List segmentation masks for an initialized imaging handle

List segmentation masks for an initialized imaging handle

## Usage

``` r
ds.imaging.masks(conns, dataset_id = NULL, handle = "img")
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character or NULL; retained for source compatibility.

- handle:

  Character; initialized imaging handle (default `"img"`).

## Value

Named list of per-server data.frames.
