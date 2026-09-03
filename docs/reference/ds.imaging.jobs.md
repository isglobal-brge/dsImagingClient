# Legacy cross-workflow job listing

Legacy cross-workflow job listing

## Usage

``` r
ds.imaging.jobs(conns)
```

## Arguments

- conns:

  DSI connections object.

## Value

This function always errors. Keep the workflow symbol returned by a
dsImaging submission and use its domain-specific status method instead.

## Examples

``` r
if (FALSE) { # \dontrun{
# conns <- DSI::datashield.login(...)  # live DataSHIELD session
ds.imaging.jobs(conns)
} # }
```
