# Convert DICOM series to NIfTI images

Submits a dsHPC-backed conversion job. The runner uses `dcm2niix` when
available and falls back to SimpleITK series reading.

## Usage

``` r
ds.imaging.dicom.convert(
  conns,
  dataset_id,
  dicom_asset = "dicom",
  output_asset = "nifti_images",
  converter = "auto",
  visibility = "global",
  alias = NULL
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character; dataset identifier.

- dicom_asset:

  Character; manifest asset containing DICOM series.

- output_asset:

  Character; name for the published NIfTI image asset.

- converter:

  Character; `"auto"`, `"dcm2niix"`, or `"simpleitk"`.

- visibility:

  Character; job visibility label.

- alias:

  Character or NULL; optional asset alias.

## Value

A dshpc_submission.
