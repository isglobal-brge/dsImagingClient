# Validate Imaging Dataset

Calls `imagingValidateDS()` on each server to run security and integrity
checks on the imaging dataset.

## Usage

``` r
ds.imaging.validate(conns, handle = "img")
```

## Arguments

- conns:

  DSI connections object.

- handle:

  Character; symbol name of the imaging handle (default `"img"`).

## Value

Named list of per-server validation results.
