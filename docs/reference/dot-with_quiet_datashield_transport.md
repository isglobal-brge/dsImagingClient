# Run a DataSHIELD transport without deparsed expressions or remote errors

DSI may print the full call expression when progress reporting is
enabled. Imaging calls carry opaque handles and base64-encoded workflow
requests, so both global diagnostic options are disabled only for the
transport call and restored even when it fails.

## Usage

``` r
.with_quiet_datashield_transport(code)
```
