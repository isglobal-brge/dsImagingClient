# Install a segmentation model on the server (admin only)

Downloads model weights to the hospital's server. Requires the admin key
to be configured with `dshpc.admin_key` or `DSHPC_ADMIN_KEY`.

## Usage

``` r
ds.imaging.install_model(conns, admin_key, provider, task)

ds.radiomics.install_model(conns, admin_key, provider, task)
```

## Arguments

- conns:

  DSI connections object.

- admin_key:

  Character; the admin key matching `dshpc.admin_key` or
  `DSHPC_ADMIN_KEY` on the server.

- provider:

  Character; "totalsegmentator", "lungmask", "monai", "nnunetv2".

- task:

  Character; model/task name (e.g. "total", "R231").

## Value

Named list with install status per server.
