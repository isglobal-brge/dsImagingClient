# dsImagingClient 0.3.4

* Imaging Resource initialization is backend-neutral across Opal and
  Armadillo and removes Armadillo's transient `R`/`rds` loader symbols on
  success and rollback. Pre-existing symbols are never overwritten or removed.

# dsImagingClient 0.3.3

* Added `ds.imaging.feature_view()` and its exact cleanup helper so complete
  derived feature assets can be handed to dsFlower as opaque, patient-bound
  session capabilities without exposing a data frame in the workspace.
  Multi-column selections are encoded as one literal transport argument, so
  they remain usable with the server's strict expression boundary.
* The packaged validation demo now publishes atomically and includes the
  mandatory patient identifier used by the current collection contract.

# dsImagingClient 0.3.2

* `ds.imaging.radiomics.segment_and_extract()` now calls the dedicated
  `imagingProcessSegmentAndExtractDS` workflow and forwards `image_asset`.
* Collection lifecycle responses now validate their closed public schema before
  returning server-provided states or asset references.

* Initialization now uses a deterministic protocol-owned temporary resource
  symbol. `ds.imaging.destroy()` also removes that symbol, so cleanup remains
  possible through the documented API even when both automatic removal
  attempts failed.
* Handle and workflow destruction remains retryable when the server cleanup
  succeeded but the client-side workspace removal failed: the server now
  reassigns an opaque tombstone until exact removal is confirmed.
* `ds.imaging.summary()` now reports only handle-scoped dataset metadata and
  catalog availability; it no longer calls the deliberately retired global
  job-listing API.
* Bundled synthetic validation evidence is explicitly labelled as a sanitized
  fixture and contains no dsHPC bearer identifiers or node-local paths.

* Imaging workflows now carry an initialized `handle` (default `"img"`).
  Optional legacy `dataset_id` values are verified against that handle by the
  server.
* Collection radiomics is submitted once through
  `imagingProcessRadiomicsCollectionDS()` and controlled by its opaque symbol;
  discovery, identifiers, fingerprints, and batching remain server-side.
  The server creates dsHPC job identifiers, and collection publication is
  all-or-nothing.
* Asset catalog and loading calls are handle-scoped. Global dataset registry
  listing is retired; initialize an authorized resource with
  `ds.imaging.init()` instead.
* `ds.imaging.destroy()` and workflow lifecycle helpers provide exact per-node
  cleanup acknowledgement and retain uncertain handles for an explicit retry.
* Calls carrying opaque handles or encoded workflow requests suppress DSI
  expression progress and raw remote diagnostics for the transport call, then
  restore the caller's diagnostic options.

# dsImagingClient 0.3.1

* `.ds_safe_aggregate()` no longer swallows per-server failures silently: one
  `warning()` is emitted per failed server at call time, in addition to the
  `ds_errors` attribute consumed by `.ds_first_result()`.
* Documentation: runnable `\donttest` examples added to the key analyst verbs
  (`ds.imaging.init`, `ds.imaging.datasets`, `ds.imaging.metadata`,
  `ds.imaging.validate`, `ds.imaging.radiomics.process_collection`,
  `ds.imaging.radiomics.load_features`, `ds.imaging.catalog`,
  `ds.imaging.jobs`).
