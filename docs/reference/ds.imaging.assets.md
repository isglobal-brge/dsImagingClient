# List Dataset Assets

Calls `imagingAssetsDS()` on each server to retrieve the names and types
of assets available in the imaging dataset.

## Usage

``` r
ds.imaging.assets(conns, handle = "img")
```

## Arguments

- conns:

  DSI connections object.

- handle:

  Character; symbol name of the imaging handle (default `"img"`).

## Value

Named list of per-server data.frames.
