# Check status of a collection workflow

Use this with the symbol returned by
[`ds.imaging.radiomics.process_collection()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.radiomics.process_collection.md),
including after reconnecting to a session.

## Usage

``` r
ds.imaging.radiomics.collection_status(conns, symbol)
```

## Arguments

- conns:

  DSI connections object.

- symbol:

  Character; server-side collection workflow symbol.

## Value

A list containing `state`, `is_done`, and optionally `asset_id`; or a
named list of these responses for multiple servers.
