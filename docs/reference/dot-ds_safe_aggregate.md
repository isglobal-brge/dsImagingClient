# Resilient datashield.aggregate that tolerates per-server failures

Resilient datashield.aggregate that tolerates per-server failures

## Usage

``` r
.ds_safe_aggregate(conns, expr, ...)
```

## Arguments

- conns:

  DSI connections object.

- expr:

  A call expression, or a method name with arguments in `...`.

- ...:

  Arguments used when `expr` is a method name.

## Value

Named list of results.
