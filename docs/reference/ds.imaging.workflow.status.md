# Get disclosure-controlled imaging workflow status

Returns only a coarse state and completion flag from every server. After
a successful private publication, each server also returns its own
opaque asset identifier; no dsHPC job id, bearer, path, roster, or
progress count crosses the DataSHIELD boundary.

## Usage

``` r
ds.imaging.workflow.status(conns, workflow)
```

## Arguments

- conns:

  DSI connections object.

- workflow:

  A workflow submission returned by a `ds.imaging.*` function, or its
  server-side symbol.

## Value

One status list for a single server, or a named list by server.
