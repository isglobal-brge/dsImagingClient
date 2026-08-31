# dsImagingClient 0.3.1

* `.ds_safe_aggregate()` no longer swallows per-server failures silently: one
  `warning()` is emitted per failed server at call time, in addition to the
  `ds_errors` attribute consumed by `.ds_first_result()`.
* Documentation: runnable `\donttest` examples added to the key analyst verbs
  (`ds.imaging.init`, `ds.imaging.datasets`, `ds.imaging.metadata`,
  `ds.imaging.validate`, `ds.imaging.radiomics.process_collection`,
  `ds.imaging.radiomics.load_features`, `ds.imaging.catalog`,
  `ds.imaging.jobs`).
