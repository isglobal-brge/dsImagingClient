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

  Character; symbol name for the imaging handle (default `"img"`).

## Value

`TRUE`, invisibly. The initialized imaging object remains on every
server under `symbol` for imaging operations or independent downstream
consumers.

## Examples

``` r
if (FALSE) { # \dontrun{
# conns <- DSI::datashield.login(...)  # live DataSHIELD session
ds.imaging.init(conns, resource = "lung_ct_res", symbol = "img")
ds.imaging.metadata(conns, "img")
} # }
```
