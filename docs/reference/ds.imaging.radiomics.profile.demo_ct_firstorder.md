# Lightweight CT first-order demo profile

Uses Original image first-order features only. This is intended for
plug-and-play demos and constrained Rock containers where wavelet/LoG
feature families can be too memory intensive.

## Usage

``` r
ds.radiomics.profile.demo_ct_firstorder(bin_width = 25)

ds.imaging.radiomics.profile.demo_ct_firstorder(bin_width = 25)
```

## Arguments

- bin_width:

  Numeric; histogram bin width (default 25).

## Value

A radiomics profile spec.
