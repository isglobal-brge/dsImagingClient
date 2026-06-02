# Run RTDOSE and RTPLAN summaries

Run RTDOSE and RTPLAN summaries

## Usage

``` r
ds.imaging.rt.dose(
  conns,
  dataset_id,
  dose_asset = "rt_dose",
  plan_asset = "rt_plan",
  mask_asset = NULL,
  output_asset = "rt_dose_metrics",
  visibility = "private",
  alias = NULL
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character; dataset identifier.

- dose_asset:

  Character; RTDOSE asset or alias.

- plan_asset:

  Character; RTPLAN asset or alias.

- mask_asset:

  Character or NULL; optional mask asset for dose metrics.

- output_asset:

  Character; published dose table asset name.

- visibility:

  Character; job visibility label.

- alias:

  Character or NULL; optional asset alias.

## Value

A dshpc_submission.
