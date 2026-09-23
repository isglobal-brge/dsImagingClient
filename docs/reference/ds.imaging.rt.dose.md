# Run RTDOSE and RTPLAN summaries

The complete per-ROI dose table remains server-side. It can be assigned to
the authorized session with `ds.imaging.load_asset()`, under the same patient
admission and downstream disclosure controls as radiomics tables. Declare
`roi_labels` and their corresponding `mask_labels` to request one row for
every sample and public ROI label, with `dose_min`, `dose_max`, `dose_mean`,
`dose_std` and `dose_voxels`. Unmatched labels retain a row with missing
measurements and zero voxels; undeclared private labels are ignored. No labels
are discovered from masks. Without this public schema, legacy rows remain
`whole_grid` and one optional `mask`, the union of positive mask voxels.

## Usage

``` r
ds.imaging.rt.dose(
  conns,
  dataset_id = NULL,
  dose_asset = "rt_dose",
  plan_asset = "rt_plan",
  mask_asset = NULL,
  output_asset = "rt_dose_metrics",
  visibility = "shared",
  alias = NULL,
  handle = "img",
  roi_labels = NULL,
  mask_labels = NULL,
  mask_assets = NULL
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character or NULL; optional dataset identifier. The server derives it
  from `handle` and verifies any supplied value.

- dose_asset:

  Character; RTDOSE asset or alias.

- plan_asset:

  Character; RTPLAN asset or alias.

- mask_asset:

  Character or NULL; one mapped mask asset for dose metrics. In labelled
  mode, it supplies every requested label. Mutually exclusive with `mask_assets`.

- output_asset:

  Character; published dose table asset name.

- visibility:

  Character; job visibility label.

- alias:

  Character or NULL; optional asset alias.

- handle:

  Character; initialized imaging handle (default `"img"`).

- roi_labels:

  Character vector or NULL; public ROI vocabulary of 1 through 128 unique
  names, each beginning with a letter and containing only letters, numbers,
  underscores, dots or hyphens, up to 64 characters.

- mask_labels:

  Integer vector or NULL; positive voxel values paired with `roi_labels`,
  up to 2147483647.

- mask_assets:

  Character vector or NULL; one mapped mask asset per ROI, paired with
  `roi_labels` and `mask_labels`. Assets may repeat when selecting different
  values; the same asset/value pair cannot repeat.

## Value

A domain-mediated workflow submission handle.
