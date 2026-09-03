# Recover a collection workflow

Reconciles the server-owned workflow state and resumes eligible work.

## Usage

``` r
ds.imaging.radiomics.collection_recover(conns, symbol)
```

## Arguments

- conns:

  DSI connections object.

- symbol:

  Character; server-side collection workflow symbol.

## Value

A list containing `state`, `is_done`, and optionally `asset_id`; or a
named list of these responses for multiple servers.
