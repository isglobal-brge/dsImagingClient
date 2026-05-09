# Compute a derivation hash (client-side copy)

Identical to dsImaging::compute_derivation_hash but avoids pulling the
full dsImaging dependency (arrow, aws.s3, DBI, etc.) into the client
installation.

## Usage

``` r
.compute_derivation_hash(...)
```
