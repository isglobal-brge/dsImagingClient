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
- `LUNG1_RUN_JOBS=FALSE` to reuse `datashield_radiomics_result.rds`
- `DSIMAGING_RESOURCE_ENDPOINT=http://minio.local:9000`
- `OPAL_USER=administrator`, `OPAL_PASSWORD=admin123`

## Current Validation

The smoke run in this workspace used 9 real LUNG1 patients, split 3 per site.
All 9 PyRadiomics jobs completed, all three collection assets were published,
and federated means matched the local central baseline to floating-point
tolerance. See `RESULTS.md` for the observed numbers.

This 9-patient run is an engineering validation, not a scientific replication
of the Aerts/Shi survival result. For a manuscript-style replication, run at
least `--n-per-site 12`, and preferably `--all-patients` for the full public
LUNG1 cohort.
