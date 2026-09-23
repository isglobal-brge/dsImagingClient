# dsImagingClient

`dsImagingClient` is the client-side DataSHIELD package for clinical imaging.
It initializes imaging resources, queries dataset/asset metadata, builds
segmentation and radiomics specs, submits dsHPC-backed image workflows, and
monitors or publishes derived imaging assets.

## Core Usage

```r
library(dsImagingClient)

ds.imaging.init(conns, resource = "dsdemo.imgct_demo", symbol = "img")
ds.imaging.metadata(conns, handle = "img")
ds.imaging.assets(conns, handle = "img")
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
  segmenter = segmenter,
  profile = profile,
  batch_size = 1L,
  timeout = 0,
  handle = "img"
)

ds.imaging.radiomics.collection_status(conns, result$symbol)
ds.imaging.radiomics.collection_recover(conns, result$symbol)
published <- stats::setNames(lapply(names(conns), function(server) {
  ds.imaging.radiomics.collection_publish(conns[server], result$symbol)
}), names(conns))
ds.imaging.radiomics.features(conns, handle = "img")

# Assign the published feature table for standard DataSHIELD analysis.
for (server in names(conns)) {
  ds.imaging.radiomics.load_features(
    conns[server],
    asset_id = published[[server]]$asset_id,
    symbol = "rad",
    include_metadata = TRUE,
    syntactic_names = TRUE,
    handle = "img"
  )
}
```

`collection_status()` already reconciles server-side state. Use
`collection_recover()` to explicitly re-run that reconciliation after a crash or
disconnect. Status, recovery, and publication accept only the opaque workflow
symbol returned by `process_collection()`; image identifiers and fingerprints
remain server-side. Status and recovery expose only `state`, `is_done`, an
optional `asset_id`, and the durable public `tracking_id`; publication is
all-or-nothing. The public logical queue can be rediscovered without an
execution bearer:

```r
jobs <- ds.imaging.jobs(conns)  # complete imaging history only
ds.imaging.job.status(conns, result$tracking_id)

# Manual paging is available when needed; use one node at a time.
page <- ds.imaging.jobs(conns["site1"], limit = 100L, all = FALSE)
if (page$has_more) {
  next_page <- ds.imaging.jobs(
    conns["site1"], limit = 100L, cursor = page$next_cursor, all = FALSE)
}

# Rebind a still-running collection after reconnecting and initializing img.
recovered <- ds.imaging.workflow.recover(
  conns, result$tracking_id, handle = "img", symbol = "recovered_collection")
ds.imaging.radiomics.collection_status(conns, recovered)
```

When the dataset was published with clinical/sample metadata,
`include_metadata = TRUE` assigns a single server-side data frame joined on
`sample_id`. `syntactic_names = TRUE` repairs names such as wavelet feature
columns containing `-`, making the table ready for formula-based DataSHIELD
analysis functions.

For dsFlower, an opaque feature view can also join an existing server-side
clinical table without returning either table to the client:

```r
ds.imaging.feature_view(
  conns,
  asset_id = published,
  symbol = "flower_features",
  handle = "img",
  clinical_symbol = "clinical",
  clinical_id_col = "patient_id",
  clinical_columns = c("age", "stage"),
  target_col = "diagnosis",
  target_levels = c("control", "case")
)
```

A validated output can also be recovered in a later DataSHIELD session using
only its public tracking id. `dsHPCClient` assigns an opaque reference and
`dsImagingClient` passes that server symbol directly to `dsImaging`:

```r
dsHPCClient::ds.hpc.load_output(
  conns, result$tracking_id,
  output_name = "output_001", symbol = "shared_asset")

ds.imaging.feature_view(
  conns, asset_symbol = "shared_asset", symbol = "flower_features",
  handle = "img")

# Or materialize the validated asset through dsImaging for another workflow.
ds.imaging.load_asset(
  conns, asset_symbol = "shared_asset", symbol = "radiomics_data",
  handle = "img")
```

The opaque reference contains no image bytes, node path, asset id, provider
reference, credential, or execution-job id. Raw data does not cross the
client; each consuming DataSHIELD package remains responsible for disclosure
control in its own registered methods.

The clinical table contract is one row per patient. Linkage is anchored to the
sealed dsImaging patient roster, never to image sample rows. Missing, duplicate,
or unknown patient keys do not change success/failure or shrink the image
cohort: their values are totalised as missing and dsFlower applies its public
feature/target defaults before patient-level DP training. Extra clinical rows
are ignored.

Omit `clinical_symbol` and the other clinical arguments to retain the original
manifest-metadata feature-view workflow. For a numeric outcome, set
`target_col` and leave `target_levels = NULL`.

`timeout = 0` starts the workflow and returns immediately. The live workflow
symbol remains session-bound, while its public tracking id and validated
server-reusable output are durable. After reconnecting, use
`ds.imaging.jobs()` or the saved tracking id and the opaque-output flow above.
Per-image child jobs and their exact cardinality remain hidden.

To use existing manual or model-derived masks from `dsimaging-store`, publish
them under `source/masks/` and use:

```r
segmenter <- ds.imaging.segmenter.existing_mask("masks")
```

## Direct Workflows

- `ds.imaging.dicom.convert()`
- `ds.imaging.preprocess()`
- `ds.imaging.mask.operation()`
- `ds.imaging.qc.metrics()`
- `ds.imaging.qc.visuals()`
- `ds.imaging.rt.convert()`
- `ds.imaging.rt.dose()`
- `ds.imaging.spatial.process()`
- `ds.imaging.wsi.tile()`
- `ds.imaging.embeddings.extract()`
- `ds.imaging.segment()`
- `ds.imaging.radiomics.extract()`
- `ds.imaging.radiomics.segment_and_extract()`
- `ds.imaging.radiomics.process_collection()`
- `ds.imaging.radiomics.collection_status()`
- `ds.imaging.radiomics.collection_publish()`
- `ds.imaging.radiomics.load_features()`

## Preprocessing, Masks, And QC

```r
ds.imaging.dicom.convert(conns, dicom_asset = "dicom", handle = "img")

ds.imaging.preprocess(
  conns,
  operations = c("resample", "clamp", "float32"),
  spacing = c(1, 1, 1),
  lower = -1000,
  upper = 400,
  handle = "img"
)

ds.imaging.mask.operation(
  conns,
  operation = "label_select",
  mask_asset = "totalseg_masks",
  labels = c(10, 11),
  handle = "img"
)

ds.imaging.qc.metrics(conns, mask_asset = "lung_masks", handle = "img")

ds.imaging.qc.visuals(conns, mask_asset = "lung_masks", max_tiles = 64,
  max_size = 192, handle = "img")
ds.imaging.embeddings.extract(conns, handle = "img")
ds.imaging.spatial.process(
  conns,
  operations = c("resample", "crop_to_mask"),
  mask_asset = "lung_masks",
  spacing = c(1, 1, 1),
  handle = "img"
)

# Radiotherapy assets can become reusable masks/tables.
ds.imaging.rt.convert(conns, rt_asset = "rt_struct", rois = "GTV-1",
  handle = "img")
ds.imaging.rt.dose(conns, mask_asset = "rt_masks", handle = "img")

# WSI/pathology studies can publish tile manifests and optional tile PNGs.
ds.imaging.wsi.tile(conns, tile_size = 512, max_tiles = 1000, handle = "img")

# An administrator-installed MONAI bundle must return one mask per sample.
ds.imaging.segment(conns,
  segmenter = ds.imaging.segmenter.monai_bundle("registered_bundle"), handle = "img")
```

These routes require exact sample-to-patient associations in the sealed
collection roster. Each DICOM series enumerates and hashes every instance;
RTSTRUCT, RTDOSE and RTPLAN assets must match the sample's canonical patient
identifier and DICOM references. Ambiguous or incomplete inputs fail closed.
RT conversion produces one combined binary ROI mask per sample. DICOM SEG
conversion remains unavailable.

The analyst receives opaque workflow and asset references. Masks, slides,
tiles, per-slide tile counts, local manifests and paths remain server-side.
WSI `max_tiles` is a per-slide cap. A dose asset is a complete per-ROI table
that `ds.imaging.load_asset()` can assign in the authorized server session;
its individual rows never cross through an imaging aggregate method.
Downstream DataSHIELD methods retain their disclosure controls, and minimum
cohort sizes count distinct patients rather than tiles or ROI rows.

QC `max_tiles` defaults to 64 (range 1–1024); `max_size` defaults to 192 pixels
(range 16–4096). All inputs are validated, then thumbnails are rendered in
stable sample order up to the cap. The complete output mapping records capped
samples explicitly. PNG names are pseudonymous; the unchanged local CSV lists
rendered samples and stays server-side. `max_images` remains deprecated and
ignored.

Use `ds.imaging.radiomics.profile.aerts_signature(version = "v2")` for the
published four-feature selection: original Energy, Compactness2 (sphericity
cubed), original GLRLM GrayLevelNonUniformity and wavelet-HLH GLRLM
GrayLevelNonUniformity. PyRadiomics settings match the historical profile.
The default `version = "v1"` preserves the Aerts-inspired historical selection
(Energy, Compactness1 and original/wavelet-HLH RunLengthNonUniformity) and its
byte-identical YAML. These profiles select features; they do not contain fitted
prognostic coefficients. The client supplies v1's four-feature filter; a direct
server v1 request without that filter retains the broader YAML candidate set.
The server enforces v2's exact four-feature selection.
[Aerts et al. (2014)](https://doi.org/10.1038/ncomms5006)
names the signature; its [supplement](https://www.ebi.ac.uk/europepmc/webservices/rest/PMC4059926/supplementaryFiles)
identifies Compactness2 in Figure 1 and feature 16. The
[PyRadiomics replication](https://pmc.ncbi.nlm.nih.gov/articles/PMC6805885/)
documents the equivalent sphericity-cubed definition.

The public client surface is `ds.imaging.*`; the former `ds.radiomics.*` and
`ds.segmenter.*` compatibility wrappers have been retired before production use.

## Public LUNG1 Study Demo

A reproducible TCIA NSCLC-Radiomics/LUNG1 federated radiomics study is bundled
under `inst/demos/lung1_federated_study`. It prepares CT + RTSTRUCT `GTV-1`
masks, publishes three simulated sites with `dsimaging-admin`, runs
dsHPC-backed Aerts-inspired v1 radiomics through `dsImaging`, and compares the federated
DataSHIELD feature summaries with a central PyRadiomics baseline. The historical
full validation used 422 public LUNG1 patients that passed conversion and is
based on the public Aerts/LUNG1 radiomics workflow. Its historical feature
selection uses RunLengthNonUniformity and Compactness1; it is not the published
four-feature selection now available as v2. No historical demonstration was
rerun for the 0.5.0 admission changes.

The demo also includes `run_lung1_linked_dslite.R`, a one-node engineering
acceptance that keeps `clinical.csv` as a normal DataSHIELD table, publishes
only structural imaging metadata, builds an opaque radiomics feature view, and
trains a patient-DP dsFlower logistic model. It is a systems demonstration, not
clinical validation or a three-node federation.
