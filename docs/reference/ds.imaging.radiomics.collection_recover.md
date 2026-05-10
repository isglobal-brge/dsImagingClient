# Recover a running collection generation

Reconciles server-side job state, requeues stale claimed items left by
an interrupted submitter, and nudges the server-side drip-feed loop.

## Usage

``` r
ds.imaging.radiomics.collection_recover(conns, generation_id)
```

## Arguments

- conns:

  DSI connections object.

- generation_id:

  Character; the generation_id.

## Value

Named list with progress info.
