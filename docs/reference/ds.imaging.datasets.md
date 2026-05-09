# List Available Imaging Datasets

Calls `imagingListDatasetsDS()` on each server to retrieve the list of
available imaging datasets.

## Usage

``` r
ds.imaging.datasets(conns)
```

## Arguments

- conns:

  DSI connections object.

## Value

Named list of per-server data.frames with available datasets.
