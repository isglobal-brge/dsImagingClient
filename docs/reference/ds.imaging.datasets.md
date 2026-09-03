# Dataset registry listing (deprecated)

Imaging access is capability-scoped to a resource initialized with
[`ds.imaging.init()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.init.md).
Global registry enumeration is not available.

## Usage

``` r
ds.imaging.datasets(conns)
```

## Arguments

- conns:

  DSI connections object.

## Value

This function always errors with migration guidance.

## Examples

``` r
if (FALSE) { # \dontrun{
# conns <- DSI::datashield.login(...)  # live DataSHIELD session
ds.imaging.init(conns, resource = "PROJECT.images", symbol = "img")
ds.imaging.metadata(conns, handle = "img")
} # }
```
