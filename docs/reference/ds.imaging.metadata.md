# Get Imaging Dataset Metadata

Calls `imagingMetadataDS()` on each server to retrieve disclosure-safe
metadata about the imaging dataset.

## Usage

``` r
ds.imaging.metadata(conns, handle = "img")
```

## Arguments

- conns:

  DSI connections object.

- handle:

  Character; symbol name of the imaging handle (default `"img"`).

## Value

Named list of per-server metadata.

## Examples

``` r
# \donttest{
# conns <- DSI::datashield.login(...)  # live DataSHIELD session
ds.imaging.init(conns, resource = "lung_ct_res", symbol = "img")
#> Warning: restarting interrupted promise evaluation
#> Warning: restarting interrupted promise evaluation
#> Error: object 'conns' not found
str(ds.imaging.metadata(conns, "img"))
#> Error: object 'conns' not found
# }
```
