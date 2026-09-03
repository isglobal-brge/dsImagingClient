# Legacy label-set discovery

Unrestricted manifest label discovery is retired. The server admits only
the manifest-declared label through handle-scoped workflows.

## Usage

``` r
ds.imaging.labels(conns, symbol = "img")
```

## Arguments

- conns:

  DSI connections object.

- symbol:

  Character; the imaging handle symbol (default "img").

## Value

This function always errors with migration guidance.
