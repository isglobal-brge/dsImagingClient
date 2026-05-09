# Initialize Imaging Dataset Handle

Assigns an imaging resource on each server and creates an imaging handle
via `imagingInitDS()`.

## Usage

``` r
ds.imaging.init(conns, resource, symbol = "img")
```

## Arguments

- conns:

  DSI connections object.

- resource:

  Character; name of the Opal resource to assign.

- symbol:

  Character; symbol name for the imaging handle (default `"imaging"`).

## Value

Named list of per-server results (invisible).
