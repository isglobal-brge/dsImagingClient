# Aerts 4-feature CT radiomic signature profile

Matches the public LUNG1 / Aerts-signature replication path: bin width
25, no normalisation, no resampling, Original + Wavelet image types, and
the published firstorder/shape/GLRLM feature classes.

## Usage

``` r
ds.imaging.radiomics.profile.aerts_signature(bin_width = 25)
```

## Arguments

- bin_width:

  Numeric; histogram bin width (default 25).

## Value

A radiomics profile spec.
