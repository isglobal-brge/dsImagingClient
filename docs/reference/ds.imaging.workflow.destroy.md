# Destroy a completed imaging workflow reference

Removes the session-bound workflow capability on every server. Active
work is retained and reported as an error; it is never silently
cancelled.

## Usage

``` r
ds.imaging.workflow.destroy(conns, workflow)
```

## Arguments

- conns:

  DSI connections object.

- workflow:

  A workflow submission returned by a `ds.imaging.*` function, or its
  server-side symbol.

## Value

`TRUE`, invisibly.
