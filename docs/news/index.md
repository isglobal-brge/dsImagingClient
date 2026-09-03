# Changelog

## dsImagingClient 0.3.2

- [`ds.imaging.radiomics.segment_and_extract()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.radiomics.segment_and_extract.md)
  now calls the dedicated `imagingProcessSegmentAndExtractDS` workflow
  and forwards `image_asset`.

- Collection lifecycle responses now validate their closed public schema
  before returning server-provided states or asset references.

- Initialization now uses a deterministic protocol-owned temporary
  resource symbol.
  [`ds.imaging.destroy()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.destroy.md)
  also removes that symbol, so cleanup remains possible through the
  documented API even when both automatic removal attempts failed.

- Handle and workflow destruction remains retryable when the server
  cleanup succeeded but the client-side workspace removal failed: the
  server now reassigns an opaque tombstone until exact removal is
  confirmed.

- [`ds.imaging.summary()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.summary.md)
  now reports only handle-scoped dataset metadata and catalog
  availability; it no longer calls the deliberately retired global
  job-listing API.

- Bundled synthetic validation evidence is explicitly labelled as a
  sanitized fixture and contains no dsHPC bearer identifiers or
  node-local paths.

- Imaging workflows now carry an initialized `handle` (default `"img"`).
  Optional legacy `dataset_id` values are verified against that handle
  by the server.

- Collection radiomics is submitted once through
  `imagingProcessRadiomicsCollectionDS()` and controlled by its opaque
  symbol; discovery, identifiers, fingerprints, and batching remain
  server-side. The server creates dsHPC job identifiers, and collection
  publication is all-or-nothing.

- Asset catalog and loading calls are handle-scoped. Global dataset
  registry listing is retired; initialize an authorized resource with
  [`ds.imaging.init()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.init.md)
  instead.

- [`ds.imaging.destroy()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.destroy.md)
  and workflow lifecycle helpers provide exact per-node cleanup
  acknowledgement and retain uncertain handles for an explicit retry.

- Calls carrying opaque handles or encoded workflow requests suppress
  DSI expression progress and raw remote diagnostics for the transport
  call, then restore the caller’s diagnostic options.

## dsImagingClient 0.3.1

- [`.ds_safe_aggregate()`](https://isglobal-brge.github.io/dsImagingClient/reference/dot-ds_safe_aggregate.md)
  no longer swallows per-server failures silently: one
  [`warning()`](https://rdrr.io/r/base/warning.html) is emitted per
  failed server at call time, in addition to the `ds_errors` attribute
  consumed by
  [`.ds_first_result()`](https://isglobal-brge.github.io/dsImagingClient/reference/dot-ds_first_result.md).
- Documentation: runnable `\donttest` examples added to the key analyst
  verbs (`ds.imaging.init`, `ds.imaging.datasets`,
  `ds.imaging.metadata`, `ds.imaging.validate`,
  `ds.imaging.radiomics.process_collection`,
  `ds.imaging.radiomics.load_features`, `ds.imaging.catalog`,
  `ds.imaging.jobs`).
