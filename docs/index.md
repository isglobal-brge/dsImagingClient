# dsImagingClient

`dsImagingClient` is the client-side DataSHIELD package for clinical
imaging. It initializes imaging resources, queries dataset/asset
metadata, builds segmentation and radiomics specs, submits dsHPC-backed
image workflows, and monitors or publishes derived imaging assets.

## Core Usage

``` r

library(dsImagingClient)

ds.imaging.init(conns, resource = "dsdemo.imgct_demo", symbol = "img")
ds.imaging.datasets(conns)
ds.imaging.capabilities(conns)
```

## Segmentation And Radiomics

``` r

segmenter <- ds.imaging.segmenter.ct_lung_threshold(
  threshold = -320,
  max_components = 2L,
  min_voxels = 1000L
)

profile <- ds.imaging.radiomics.profile.demo_ct_firstorder()

result <- ds.imaging.radiomics.process_collection(
  conns,
  dataset_id = NULL,          # use the dataset id from the imaging handle
  segmenter = segmenter,
  profile = profile,
  batch_size = 1L,
  timeout = 0
)

ds.imaging.radiomics.collection_status(conns, result$generation_id)
ds.imaging.radiomics.collection_recover(conns, result$generation_id)
ds.imaging.radiomics.collection_publish(
  conns, result$generation_id, result$dataset_id
)
ds.imaging.radiomics.features(conns, result$dataset_id)

# Assign the published feature table for standard DataSHIELD analysis.
ds.imaging.radiomics.load_features(
  conns,
  dataset_id = result$dataset_id,
  asset_id = "<asset_id_or_alias>",
  symbol = "rad",
  include_metadata = TRUE,
  syntactic_names = TRUE
)
```

`collection_status()` already reconciles server-side state. Use
`collection_recover()` to explicitly re-run that reconciliation after a
crash or disconnect. Use
`collection_cancel(conns, generation_id, admin_key)` only for operator
cleanup; it is protected by the same `dshpc.admin_key` or
`DSHPC_ADMIN_KEY` used by `dsHPCClient` admin methods.

When the dataset was published with clinical/sample metadata,
`include_metadata = TRUE` assigns a single server-side data frame joined
on `sample_id`. `syntactic_names = TRUE` repairs names such as wavelet
feature columns containing `-`, making the table ready for formula-based
DataSHIELD analysis functions.

`timeout = 0` starts the workflow and returns immediately. The
server-side publisher keeps feeding the next pending image jobs as
previous jobs finish. For store-backed resources, the generation carries
the manifest/backend context needed by the worker, so the analyst can
disconnect after the first submission.

To use existing manual or model-derived masks from `dsimaging-store`,
publish them under `source/masks/` and use:

``` r

segmenter <- ds.imaging.segmenter.existing_mask("masks")
```

## Direct Workflows

- [`ds.imaging.dicom.convert()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.dicom.convert.md)
- [`ds.imaging.preprocess()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.preprocess.md)
- [`ds.imaging.mask.operation()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.mask.operation.md)
- [`ds.imaging.qc.metrics()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.qc.metrics.md)
- [`ds.imaging.qc.visuals()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.qc.visuals.md)
- [`ds.imaging.rt.convert()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.rt.convert.md)
- [`ds.imaging.rt.dose()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.rt.dose.md)
- [`ds.imaging.spatial.process()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.spatial.process.md)
- [`ds.imaging.wsi.tile()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.wsi.tile.md)
- [`ds.imaging.embeddings.extract()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.embeddings.extract.md)
- [`ds.imaging.segment()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.segment.md)
- [`ds.imaging.radiomics.extract()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.radiomics.extract.md)
- [`ds.imaging.radiomics.segment_and_extract()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.radiomics.segment_and_extract.md)
- [`ds.imaging.radiomics.process_collection()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.radiomics.process_collection.md)
- [`ds.imaging.radiomics.collection_status()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.radiomics.collection_status.md)
- [`ds.imaging.radiomics.collection_publish()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.radiomics.collection_publish.md)
- [`ds.imaging.radiomics.load_features()`](https://isglobal-brge.github.io/dsImagingClient/reference/ds.imaging.load_asset.md)

## Preprocessing, Masks, And QC

``` r

ds.imaging.dicom.convert(conns, "imgct_demo", dicom_asset = "dicom")

ds.imaging.preprocess(
  conns,
  "imgct_demo",
  operations = c("resample", "clamp", "float32"),
  spacing = c(1, 1, 1),
  lower = -1000,
  upper = 400
)

ds.imaging.mask.operation(
  conns,
  "imgct_demo",
  operation = "label_select",
  mask_asset = "totalseg_masks",
  labels = c(10, 11)
)

ds.imaging.qc.metrics(conns, "imgct_demo", mask_asset = "lung_masks")

ds.imaging.qc.visuals(conns, "imgct_demo", mask_asset = "lung_masks")
ds.imaging.embeddings.extract(conns, "imgct_demo")
ds.imaging.spatial.process(
  conns,
  "imgct_demo",
  operations = c("resample", "crop_to_mask"),
  mask_asset = "lung_masks",
  spacing = c(1, 1, 1)
)

# Radiotherapy assets can become reusable masks/tables.
ds.imaging.rt.convert(conns, "lung1", rt_asset = "rt_struct", rois = "GTV-1")
ds.imaging.rt.dose(conns, "lung1", mask_asset = "rt_masks")

# WSI/pathology studies can publish tile manifests and optional tile PNGs.
ds.imaging.wsi.tile(conns, "pathology_demo", tile_size = 512, max_tiles = 1000)
```

The public client surface is `ds.imaging.*`; the former `ds.radiomics.*`
and `ds.segmenter.*` compatibility wrappers have been retired before
production use.

## Public LUNG1 Study Demo

A reproducible TCIA NSCLC-Radiomics/LUNG1 federated radiomics study is
bundled under `inst/demos/lung1_federated_study`. It prepares CT +
RTSTRUCT `GTV-1` masks, publishes three simulated sites with
`dsimaging-admin`, runs dsHPC-backed Aerts radiomics through
`dsImaging`, and compares the federated DataSHIELD feature summaries
with a central PyRadiomics baseline. The full validation path uses 422
public LUNG1 patients that passed conversion and is aligned with the
public Aerts/LUNG1 radiomics workflow rather than with a synthetic
imaging fixture.
