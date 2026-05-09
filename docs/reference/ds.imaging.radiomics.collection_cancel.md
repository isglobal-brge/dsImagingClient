# Cancel a running collection generation (admin only)

Requires the server-side `dshpc.admin_key` option or `DSHPC_ADMIN_KEY`
environment variable. This cancels dsHPC jobs belonging to the
generation and marks unfinished generation items as skipped.

## Usage

``` r
ds.radiomics.collection_cancel(
  conns,
  generation_id,
  admin_key,
  reason = "Cancelled by admin"
)

ds.imaging.radiomics.collection_cancel(
  conns,
  generation_id,
  admin_key,
  reason = "Cancelled by admin"
)
```

## Arguments

- conns:

  DSI connections object.

- generation_id:

  Character; the generation_id.

- admin_key:

  Character; admin key matching `dshpc.admin_key` or `DSHPC_ADMIN_KEY`
  on the server.

- reason:

  Character; cancellation reason.

## Value

Named list with cancellation counts.
