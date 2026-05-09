# dsImagingClient

`dsImagingClient` is the client-side DataSHIELD package for clinical imaging.
It initializes imaging resources, queries dataset/asset metadata, builds
segmentation and radiomics specs, submits dsJobs-backed image workflows, and
monitors or publishes derived imaging assets.

## Core Usage

```r
library(dsImagingClient)

ds.imaging.init(conns, resource = "demo_lung_ct", symbol = "img")
ds.imaging.datasets(conns)
ds.imaging.catalog(conns, "imgct_demo")
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
  dataset_id = "imgct_demo",
  segmenter = segmenter,
  profile = profile,
  batch_size = 1L,
  timeout = 0
)

ds.imaging.radiomics.collection_status(conns, result$generation_id)
ds.imaging.radiomics.collection_publish(conns, result$generation_id, "imgct_demo")
ds.imaging.radiomics.features(conns, "imgct_demo")
```

`timeout = 0` starts the workflow and returns immediately. The server-side
publisher keeps feeding the next pending image jobs as previous jobs finish.

## Direct Workflows

- `ds.imaging.segment()`
- `ds.imaging.radiomics.extract()`
- `ds.imaging.radiomics.segment_and_extract()`
- `ds.imaging.radiomics.process_collection()`
- `ds.imaging.radiomics.collection_status()`
- `ds.imaging.radiomics.collection_publish()`

Compatibility wrappers named `ds.radiomics.*` and `ds.segmenter.*` are exported,
but new demos should use the `ds.imaging.*` names.
