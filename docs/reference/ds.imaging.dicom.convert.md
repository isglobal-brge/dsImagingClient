# Convert one-file DICOM samples to NIfTI images

Submits a dsHPC-backed SimpleITK conversion job. Each admitted patient
sample must map to one DICOM file; multi-file series fail closed.

## Usage

``` r
ds.imaging.dicom.convert(
  conns,
  dataset_id = NULL,
  dicom_asset = "dicom",
  output_asset = "nifti_images",
  converter = "simpleitk",
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

- dicom_asset:

  Character; manifest asset containing DICOM series.

- output_asset:

  Character; name for the published NIfTI image asset.

- converter:

  Character; currently only `"simpleitk"`.

- visibility:

  Character; job visibility label.

- alias:

  Character or NULL; optional asset alias.

- handle:

  Character; initialized imaging handle (default `"img"`).

## Value

A domain-mediated workflow submission handle.
