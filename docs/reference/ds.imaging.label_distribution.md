# Disclosure-controlled label distribution for an imaging dataset

Tabulates the manifest-declared label at patient level on each node. The
server withholds the complete distribution when any cell is below its
DataSHIELD `nfilter.tab` threshold; otherwise its privacy profile may
hide, bucket, or release the admitted counts. Image pixels never leave
the node.

## Usage

``` r
ds.imaging.label_distribution(conns, symbol = "img", column = NULL)
```

## Arguments

- conns:

  DSI connections object.

- symbol:

  Character; the imaging handle symbol (default "img").

- column:

  Character or NULL; must be the dataset's declared
  `metadata.label_col`; NULL selects that declared column.

## Value

Per-server list of data.frames with columns `label` and `n`.
