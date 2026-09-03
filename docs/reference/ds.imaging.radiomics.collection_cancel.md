# Cancel a running collection workflow (admin only)

Requires the server-side `dshpc.admin_key` option or `DSHPC_ADMIN_KEY`
environment variable. This cancels dsHPC jobs belonging to the
generation and marks unfinished generation items as skipped.

## Usage

``` r
ds.imaging.radiomics.collection_cancel(
  conns,
  symbol,
  admin_key,
  reason = "Cancelled by admin"
)
```

## Arguments

- conns:

  DSI connections object.

- symbol:

  Character; server-side collection workflow symbol.

- admin_key:

  Character; admin key matching `dshpc.admin_key` or `DSHPC_ADMIN_KEY`
  on the server.

- reason:

  Character; cancellation reason.

## Value

A disclosure-controlled list containing only the coarse cancellation
state.
