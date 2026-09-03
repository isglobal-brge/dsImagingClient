# Convert RTSTRUCT or DICOM SEG assets into masks

Convert RTSTRUCT or DICOM SEG assets into masks

## Usage

``` r
ds.imaging.rt.convert(
  conns,
  dataset_id = NULL,
  rt_asset = "rt_struct",
  dicom_asset = "dicom",
  reference_asset = "images",
  rois = NULL,
  output_asset = "rt_masks",
  visibility = "private",
  alias = NULL,
  handle = "img"
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character or NULL; optional dataset identifier. The server derives it
  from `handle` and verifies any supplied value.

- rt_asset:

  Character; RTSTRUCT/DICOM SEG asset or alias.

- dicom_asset:

  Character; reference DICOM series asset for RTSTRUCT.

- reference_asset:

  Character; reference image asset for DICOM SEG geometry.

- rois:

  Character vector or NULL; ROI names to convert.

- output_asset:

  Character; published mask asset name.

- visibility:

  Character; job visibility label.

- alias:

  Character or NULL; optional asset alias.

- handle:

  Character; initialized imaging handle (default `"img"`).

## Value

A domain-mediated workflow submission handle.
