# Process an image collection with per-image deduplication

Scans a dataset's images, fingerprints them, kicks off per-image
processing jobs, and optionally waits for completion.

## Usage

``` r
ds.radiomics.process_collection(
  conns,
  dataset_id,
  segmenter,
  profile = ds.radiomics.profile.ibsi_ct_3d(),
  batch_size = 10L,
  poll_interval = 15,
  timeout = 14400,
  allow_partial = FALSE,
  visibility = "global"
)

ds.imaging.radiomics.process_collection(
  conns,
  dataset_id = NULL,
  segmenter,
  profile = ds.imaging.radiomics.profile.ibsi_ct_3d(),
  batch_size = 10L,
  poll_interval = 15,
  timeout = 14400,
  allow_partial = FALSE,
  visibility = "global"
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character; dataset identifier.

- segmenter:

  A segmenter from ds.imaging.segmenter.\*().

- profile:

  A radiomics profile from ds.imaging.radiomics.profile.\*().

- batch_size:

  Integer; images per batch (default 10).

- poll_interval:

  Numeric; seconds between status checks (default 15).

- timeout:

  Numeric; max seconds to wait (default 14400 = 4 hours). Set to 0 to
  return immediately after kick-off (fire and forget).

- allow_partial:

  Logical; publish with some failures (default FALSE).

- visibility:

  Character; asset visibility (default "global").

## Value

Named list with generation_id, asset_id (if completed), summary.

## Details

The server is self-sustaining: after the first batch is submitted,
completed jobs automatically trigger submission of the next batch. The
user can safely disconnect and reconnect later.
