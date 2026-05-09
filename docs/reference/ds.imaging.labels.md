# List available label sets for an imaging dataset

Queries the server for label sets defined in the dataset's manifest.
Returns label set names, types, column names, and descriptions. Counts
are disclosure-controlled per the server's trust profile.

## Usage

``` r
ds.imaging.labels(conns, symbol = "img")
```

## Arguments

- conns:

  DSI connections object.

- symbol:

  Character; the imaging handle symbol (default "img").

## Value

Per-server list of data.frames with columns: name, type, columns,
description.
