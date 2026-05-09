# Get Imaging Dataset Metadata

Calls `imagingMetadataDS()` on each server to retrieve disclosure-safe
metadata about the imaging dataset.

## Usage

``` r
ds.imaging.metadata(conns, handle = "imaging")
```

## Arguments

- conns:

  DSI connections object.

- handle:

  Character; symbol name of the imaging handle (default `"imaging"`).

## Value

Named list of per-server metadata.
