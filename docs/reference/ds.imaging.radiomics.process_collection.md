# Process an image collection with per-image deduplication

Assigns one disclosure-controlled collection request to each server and
optionally polls its server-side workflow symbol until processing
completes. The user can safely disconnect and reconnect with the
returned symbol.

## Usage

``` r
ds.imaging.radiomics.process_collection(
  conns,
  dataset_id = NULL,
  segmenter,
  profile = ds.imaging.radiomics.profile.ibsi_ct_3d(),
  batch_size = 10L,
  poll_interval = 15,
  timeout = 14400,
  visibility = "private",
  handle = "img",
  symbol = NULL
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character or NULL; optional dataset identifier. The server derives it
  from `handle` and verifies any supplied value.

- segmenter:

  A segmenter from ds.imaging.segmenter.\*().

- profile:

  A radiomics profile from ds.imaging.radiomics.profile.\*().

- batch_size:

  Integer; images per server-owned batch (default 10).

- poll_interval:

  Numeric; seconds between status checks (default 15).

- timeout:

  Numeric; max seconds to wait (default 14400 = 4 hours). Set to 0 to
  return immediately after kick-off (fire and forget).

- visibility:

  Compatibility argument; analytical workflows only accept `"private"`.
  Global publication is administrator-only.

- handle:

  Character; initialized imaging handle (default `"img"`).

- symbol:

  Character or NULL; target server-side workflow symbol. If NULL, a
  temporary symbol is generated.

## Value

A workflow submission handle when `timeout = 0`; otherwise the
publication response.

## Examples

``` r
if (FALSE) { # \dontrun{
# conns <- DSI::datashield.login(...)  # live DataSHIELD session
kicked <- ds.imaging.radiomics.process_collection(
  conns,
  segmenter = ds.imaging.segmenter.existing_mask("masks"),
  profile = ds.imaging.radiomics.profile.demo_ct_firstorder(),
  timeout = 0)
ds.imaging.radiomics.collection_status(conns, kicked$symbol)
ds.imaging.radiomics.collection_publish(conns, kicked$symbol)
} # }
```
