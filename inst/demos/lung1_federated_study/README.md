# LUNG1 Federated Radiomics Study Demo

This is the real-data counterpart to the local synthetic imaging smoke demo.
It uses TCIA NSCLC-Radiomics/LUNG1 CT images, RTSTRUCT `GTV-1` tumour masks,
clinical metadata, `dsimaging-store`, `dsImaging`, and dsHPC-backed radiomics
jobs across three simulated Opal/Rock sites.

The external reference point is the public LUNG1/NSCLC-Radiomics collection
used in the Aerts et al. radiomics work. This demo does not attempt to recreate
the full multi-cohort prognostic modelling study; it validates the federated
DataSHIELD execution path by comparing dsHPC-backed PyRadiomics extraction with
a central PyRadiomics baseline computed on the same prepared CT images and
tumour masks.

Sources:

- TCIA NSCLC-Radiomics collection:
  https://www.cancerimagingarchive.net/collection/nsclc-radiomics/
- NBIA public REST API:
  https://wiki.cancerimagingarchive.net/x/fILTB

The default preparation size is `--n-per-site 12`, which is the minimum useful
validation size for the Aerts 4-feature logistic path under DataSHIELD's default
`nfilter.glm = 0.33`. For quick engineering validation use `--n-per-site 3`.
For manuscript-style replication use `--all-patients`, which prepares every
available public LUNG1 patient and keeps the natural hash-based site imbalance.

## Prepare Data

```bash
python3 inst/demos/lung1_federated_study/prepare_lung1_study.py \
  --workdir /tmp/dsimaging_lung1_study \
  --n-per-site 3
```

Full-cohort plan check, without downloading DICOM data:

```bash
python3 inst/demos/lung1_federated_study/prepare_lung1_study.py \
  --workdir /tmp/dsimaging_lung1_plan \
  --all-patients \
  --dry-run
```

Full-cohort preparation:

```bash
python3 inst/demos/lung1_federated_study/prepare_lung1_study.py \
  --workdir /tmp/dsimaging_lung1_full \
  --all-patients
```

This downloads CT + RTSTRUCT series through NBIA, converts `GTV-1` masks to
NIfTI, writes `sites/site_{a,b,c}/{images,masks,metadata.csv}`, and creates a
central PyRadiomics baseline at `central/aerts_features.csv`. Downloads,
NIfTI/mask conversion, and central per-patient feature extraction are resumable;
rerunning the command continues from existing files unless `--force` is used.
Downloaded DICOM/zip files are removed after successful conversion by default
to keep full-cohort runs practical; use `--keep-raw` to retain them.

## Run Federated Pipeline

Use a `dsimaging-admin` profile created by `store setup`, or a non-secret remote
profile whose credentials are supplied by the environment/AWS credential
chain. The first pass publishes each site and writes one read-only Resource
handoff plan per node:

```bash
dsimaging-admin store setup ./lung1-store --profile-name lung1-store
export DSIMAGING_PROFILE=lung1-store
LUNG1_ONLY_PUBLISH=TRUE \
Rscript inst/demos/lung1_federated_study/run_lung1_datashield.R
```

Run `store setup` only when creating the store; reuse the profile afterwards.

The plans are written below `resource-plans/opal/`. Publication does not grant
DataSHIELD access and does not register a Resource. A node administrator reviews
each plan and applies its `opalr` command, or creates the equivalent Resource
through the dsImaging form in the Opal UI. Object-store credentials come from
the environment or Opal's protected credential fields; they are never command
arguments or plan contents. Once all three Resources exist, rerun with
`LUNG1_PUBLISH=FALSE`. The script then runs
`ds.imaging.radiomics.process_collection()` with existing masks, loads the
published radiomics assets joined with clinical metadata, and compares
federated means to the central baseline.

To prepare an Armadillo handoff instead, set the target and its non-secret
deployment identifiers on the publish-only pass:

```bash
export DSIMAGING_PROFILE=lung1-store
export LUNG1_RESOURCE_TARGET=armadillo
export LUNG1_ARMADILLO_URLS=https://armadillo-a.example.org,https://armadillo-b.example.org,https://armadillo-c.example.org
export LUNG1_ARMADILLO_CREDENTIALS_REF=imaging_store_ro
LUNG1_ONLY_PUBLISH=TRUE \
Rscript inst/demos/lung1_federated_study/run_lung1_datashield.R
```

This writes plans below `resource-plans/armadillo/`. Each plan describes the
inert marker Resource and the protected node-registry entry; the credentials
reference is an opaque server-side name, not a credential. The three URLs map
to `site_a`, `site_b`, and `site_c` in that order and must identify distinct
Armadillo nodes, so the common `imaging/resources/lung1_study` selector cannot
overwrite another site's Resource. After each administrator applies its plan,
initialise that selector from an Armadillo DataSHIELD session. The imaging and
radiomics calls are otherwise the same. The bundled live connection block
remains the local three-Opal validation harness.

Useful environment variables:

- `LUNG1_WORKDIR=/tmp/dsimaging_lung1_study`
- `LUNG1_PUBLISH=FALSE` to reuse already published store datasets
- `LUNG1_ONLY_PUBLISH=TRUE` to publish datasets, write handoff plans, and exit
  (the default whenever `LUNG1_PUBLISH=TRUE`)
- `LUNG1_PLAN_RESOURCES=FALSE` to publish without writing new handoff plans
- `LUNG1_RESOURCE_TARGET=opal|armadillo`
- `LUNG1_RESOURCE_NAME=lung1_study`
- `LUNG1_ARMADILLO_URLS=url_a,url_b,url_c` for three distinct Armadillo nodes
- `LUNG1_RUN_JOBS=FALSE` to reuse or wait/publish `datashield_radiomics_result.rds`
- `LUNG1_ASYNC=TRUE` and `LUNG1_TIMEOUT=0` to kick off jobs and disconnect
- `DSIMAGING_RESOURCE_ENDPOINT=http://minio.local:9000`
- `OPAL_USER=administrator`; inject `OPAL_PASSWORD` from a secret manager or a
  non-echoing shell prompt for the local Opal validation pass

## Current Validation

The current validation in this workspace uses the full prepared public LUNG1
cohort that passed CT + `GTV-1` mask conversion: 422 real patients split across
three simulated Opal/Rock sites (`142`, `143`, and `137` rows after loading the
published feature assets with metadata). All three collection assets were
published through `dsImagingClient`, and a federated `ds.glmSLMA()` analysis ran
successfully with three valid studies. Federated feature means matched a local
central PyRadiomics baseline over the same 422 patients to floating-point
tolerance. See `RESULTS.md` for the observed numbers.

The collection status returned by `process_collection()` applies DataSHIELD
metadata bucketing and may show `128` instead of the exact per-site count. Use
the loaded analysis table dimensions (`ds.dim("rad")`) or the local study
manifest for exact engineering validation counts.
