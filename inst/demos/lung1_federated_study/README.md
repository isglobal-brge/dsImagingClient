# LUNG1 Federated Radiomics Study Demo

This is the real-data counterpart to the local synthetic imaging smoke demo.
It uses TCIA NSCLC-Radiomics/LUNG1 CT images, RTSTRUCT `GTV-1` tumour masks,
clinical metadata, `dsimaging-store`, `dsImaging`, and dsJobs-backed radiomics
jobs across three simulated Opal/Rock sites.

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
/opt/homebrew/bin/python3.11 demos/07_lung1_federated_study/prepare_lung1_study.py \
  --workdir /tmp/dsimaging_lung1_study \
  --n-per-site 3
```

Full-cohort plan check, without downloading DICOM data:

```bash
/opt/homebrew/bin/python3.11 demos/07_lung1_federated_study/prepare_lung1_study.py \
  --all-patients \
  --dry-run
```

Full-cohort preparation:

```bash
/opt/homebrew/bin/python3.11 demos/07_lung1_federated_study/prepare_lung1_study.py \
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

```bash
Rscript demos/07_lung1_federated_study/run_lung1_datashield.R
```

The R script publishes each site with `dsimaging-admin --metadata`, registers
the Opal resource using `--resource-endpoint http://minio.local:9000`, runs
`ds.imaging.radiomics.process_collection()` with existing masks, loads the
published radiomics assets joined with clinical metadata, and compares
federated means to the central baseline.

Useful environment variables:

- `LUNG1_WORKDIR=/tmp/dsimaging_lung1_study`
- `LUNG1_PUBLISH=FALSE` to reuse already published store datasets
- `LUNG1_ONLY_PUBLISH=TRUE` to publish datasets and exit before DataSHIELD jobs
- `LUNG1_RUN_JOBS=FALSE` to reuse or wait/publish `datashield_radiomics_result.rds`
- `LUNG1_ASYNC=TRUE` and `LUNG1_TIMEOUT=0` to kick off jobs and disconnect
- `DSIMAGING_RESOURCE_ENDPOINT=http://minio.local:9000`
- `OPAL_USER=administrator`, `OPAL_PASSWORD=admin123`

## Current Validation

The current validation in this workspace uses the full prepared public LUNG1
cohort that passed CT + `GTV-1` mask conversion: 422 real patients split across
three simulated Opal/Rock sites (`142`, `143`, and `137` rows after loading the
published feature assets with metadata). All three collection assets were
published through `dsImagingClient`, and a federated `ds.glmSLMA()` analysis ran
successfully with three valid studies. See `RESULTS.md` for the observed
numbers.

The collection status returned by `process_collection()` applies DataSHIELD
metadata bucketing and may show `128` instead of the exact per-site count. Use
the loaded analysis table dimensions (`ds.dim("rad")`) or the local study
manifest for exact engineering validation counts.
