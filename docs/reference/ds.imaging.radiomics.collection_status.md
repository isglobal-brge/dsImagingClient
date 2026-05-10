# Check status of a running collection processing generation

Use this to check on a generation that was kicked off earlier,
especially after a fire-and-forget call or reconnecting to a session.

## Usage

``` r
ds.imaging.radiomics.collection_status(conns, generation_id)
```

## Arguments

- conns:

  DSI connections object.

- generation_id:

  Character; the generation_id from a prior kick-off.

## Value

Named list with progress info.
