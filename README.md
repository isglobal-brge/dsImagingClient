# dsImagingClient

`dsImagingClient` is the client-side DataSHIELD package for clinical imaging.
It initializes imaging resources, queries dataset/asset metadata, builds
segmentation and radiomics specs, submits dsJobs-backed image workflows, and
monitors or publishes derived imaging assets.

## Core Usage

```r
library(dsImagingClient)

ds.imaging.init(conns, resource = "dsdemo.imgct_demo", symbol = "img")
ds.imaging.datasets(conns)
ds.imaging.capabilities(conns)
```

## Segmentation And Radiomics

```r
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
ds.imaging.radiomics.collection_publish(
  conns, result$generation_id, result$dataset_id
)
ds.imaging.radiomics.features(conns, result$dataset_id)
```

`timeout = 0` starts the workflow and returns immediately. The server-side
publisher keeps feeding the next pending image jobs as previous jobs finish.
For store-backed resources, the generation carries the manifest/backend context
needed by the worker, so the analyst can disconnect after the first submission.

## Direct Workflows

- `ds.imaging.dicom.convert()`
- `ds.imaging.preprocess()`
- `ds.imaging.mask.operation()`
- `ds.imaging.qc.metrics()`
- `ds.imaging.segment()`
- `ds.imaging.radiomics.extract()`
- `ds.imaging.radiomics.segment_and_extract()`
- `ds.imaging.radiomics.process_collection()`
- `ds.imaging.radiomics.collection_status()`
- `ds.imaging.radiomics.collection_publish()`

## Preprocessing, Masks, And QC

```r
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
```

Compatibility wrappers named `ds.radiomics.*` and `ds.segmenter.*` are exported,
but new demos should use the `ds.imaging.*` names.
