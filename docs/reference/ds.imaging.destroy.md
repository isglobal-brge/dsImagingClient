# Destroy an Imaging Dataset Handle

Removes an initialized imaging handle, its private session registry
entry, and the deterministic temporary resource symbol used by
[`ds.imaging.init()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.init.md).
This also makes the function the documented retry path when
initialization succeeded remotely but temporary-resource removal could
not be confirmed. Dataset objects in the backing store are not changed.

## Usage

``` r
ds.imaging.destroy(conns, symbol = "img")
```

## Arguments

- conns:

  DSI connections object.

- symbol:

  Character; initialized imaging handle (default `"img"`).

## Value

`TRUE`, invisibly.
