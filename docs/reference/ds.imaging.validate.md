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

## Examples

``` r
# \donttest{
# conns <- DSI::datashield.login(...)  # live DataSHIELD session
ds.imaging.init(conns, resource = "lung_ct_res", symbol = "img")
#> Warning: restarting interrupted promise evaluation
#> Warning: restarting interrupted promise evaluation
#> Error: object 'conns' not found
str(ds.imaging.validate(conns, "img"))
#> Error: object 'conns' not found
# }
```
