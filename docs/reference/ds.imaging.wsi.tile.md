# Tile WSI/pathology images

Tile WSI/pathology images

## Usage

``` r
ds.imaging.wsi.tile(
  conns,
  dataset_id,
  wsi_asset = "wsi",
  tile_size = 512L,
  stride = tile_size,
  max_tiles = 2048L,
  tissue_threshold = 0.1,
  write_tiles = TRUE,
  output_asset = "wsi_tiles",
  visibility = "private",
  alias = NULL
)
```

## Arguments

- conns:

  DSI connections object.

- dataset_id:

  Character; dataset identifier.

- wsi_asset:

  Character; WSI asset or alias.

- tile_size:

  Integer; tile side length in pixels.

- stride:

  Integer; tile stride in pixels.

- max_tiles:

  Integer; maximum tiles per site.

- tissue_threshold:

  Numeric; minimum estimated tissue fraction.

- write_tiles:

  Logical; write PNG tile files.

- output_asset:

  Character; published tile asset name.

- visibility:

  Character; job visibility label.

- alias:

  Character or NULL; optional asset alias.

## Value

A dshpc_submission.
