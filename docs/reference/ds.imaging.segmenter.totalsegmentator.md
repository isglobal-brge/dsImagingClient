# TotalSegmentator segmenter

TotalSegmentator segmenter

## Usage

``` r
ds.segmenter.totalsegmentator(task = "total", fast = FALSE, roi_subset = NULL)

ds.imaging.segmenter.totalsegmentator(
  task = "total",
  fast = FALSE,
  roi_subset = NULL
)
```

## Arguments

- task:

  Character; segmentation task (default "total").

- fast:

  Logical; use fast mode (default FALSE).

- roi_subset:

  Character vector or NULL; specific ROIs.

## Value

A segmenter spec.
