# Convert admitted RTSTRUCT or DICOM SEG assets into masks

Each sample's RTSTRUCT or binary DICOM SEG and reference DICOM series must
have an exact sealed mapping and matching patient, study, frame and source
instance references. SEG frames must use the referenced source image grid.
Selected ROIs or segments become one union binary mask per sample; select
one segment in each separate call to publish per-segment mask assets.

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
  visibility = "shared",
  alias = NULL,
  handle = "img",
  segment_numbers = NULL
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character or NULL; optional dataset identifier. The server derives it
  from `handle` and verifies any supplied value.

- rt_asset:

  Character; RTSTRUCT or DICOM SEG asset or alias.

- dicom_asset:

  Character; explicitly mapped reference DICOM series asset.

- reference_asset:

  Deprecated compatibility argument; must remain `"images"`. Use
  `dicom_asset` for the reference series.

- rois:

  Character vector or NULL; RTSTRUCT ROI names or SEG segment labels to
  convert. Mutually exclusive with `segment_numbers`.

- output_asset:

  Character; published mask asset name.

- visibility:

  Character; job visibility label.

- alias:

  Character or NULL; optional asset alias.

- handle:

  Character; initialized imaging handle (default `"img"`).

- segment_numbers:

  Integer vector or NULL; 1 through 128 unique DICOM SEG segment numbers,
  each between 1 and 65535. When neither selection is supplied, all segments
  are combined.

## Value

A domain-mediated workflow submission handle.
