# List aliases for a dataset

Shows human-friendly names pointing to specific asset versions. Example:
"default_lung_mask" -\> asset_20260319\_...

## Usage

``` r
ds.imaging.aliases(conns, dataset_id)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character; the dataset identifier.

## Value

Named list of per-server data.frames.
