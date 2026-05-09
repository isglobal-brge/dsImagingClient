# Current Results

Run date: 2026-05-09

Dataset: TCIA NSCLC-Radiomics/LUNG1, 422 real patients with CT images and
`GTV-1` masks that passed conversion, partitioned by stable patient hash into
three simulated sites.

Command used for the final verification pass:

```sh
LUNG1_WORKDIR=/tmp/dsimaging_lung1_full \
LUNG1_DATASET_PREFIX=lung1_full_site \
LUNG1_OPAL_RESOURCE=lung1_full_study \
LUNG1_PUBLISH=FALSE \
LUNG1_RUN_JOBS=FALSE \
LUNG1_TIMEOUT=0 \
LUNG1_RUN_GLM=TRUE \
OPAL_USER=administrator \
OPAL_PASSWORD=admin123 \
Rscript dsImagingClient/inst/demos/lung1_federated_study/run_lung1_datashield.R
```

Prepared local site folders:

| site | dataset | images | masks | metadata rows |
|---|---|---:|---:|---:|
| `site_a` | `lung1_full_site_a` | 142 | 142 | 142 |
| `site_b` | `lung1_full_site_b` | 143 | 143 | 143 |
| `site_c` | `lung1_full_site_c` | 137 | 137 | 137 |

Published collection assets:

| Opal | dataset | generation | asset |
|---|---|---|---|
| `opal1` | `lung1_full_site_a` | `gen_20260509_152105_9e354de9` | `asset_20260509_165902_42b9b1a5` |
| `opal2` | `lung1_full_site_b` | `gen_20260509_152108_8cf5c55f` | `asset_20260509_170056_0bfdbf8e` |
| `opal3` | `lung1_full_site_c` | `gen_20260509_152110_b82b5785` | `asset_20260509_170057_9a3db2ab` |

DataSHIELD loaded dimensions after `ds.imaging.radiomics.load_features()` with
clinical metadata:

| source | dimensions |
|---|---:|
| `opal1` | `142 x 20` |
| `opal2` | `143 x 20` |
| `opal3` | `137 x 20` |
| combined | `422 x 20` |

The published collection parquet schema is constrained by the Aerts signature
profile to `sample_id` plus these four radiomics features; the remaining loaded
columns are clinical/sample metadata joined by `sample_id`.

Federated feature means:

The local central PyRadiomics baseline was generated after the federated run
from the same 422 NIfTI images and masks. Federated and central site-level means
match to floating-point tolerance:

| server | feature | federated mean | central mean | abs diff |
|---|---|---:|---:|---:|
| `opal1` | `original_firstorder_Energy` | 912743691.507042 | 912743691.507043 | 5.96e-07 |
| `opal1` | `original_glrlm_RunLengthNonUniformity` | 12430.8791801311 | 12430.8791801311 | 4.37e-11 |
| `opal1` | `original_shape_Compactness1` | 0.0258847932464428 | 0.0258847932464428 | 2.43e-17 |
| `opal1` | `wavelet.HLH_glrlm_RunLengthNonUniformity` | 9307.55647427235 | 9307.55647427235 | 1.82e-12 |
| `opal2` | `original_firstorder_Energy` | 924557312.867133 | 924557312.867133 | 1.19e-07 |
| `opal2` | `original_glrlm_RunLengthNonUniformity` | 13151.8800546352 | 13151.8800546352 | 1.64e-11 |
| `opal2` | `original_shape_Compactness1` | 0.0268293770986911 | 0.0268293770986911 | 1.39e-17 |
| `opal2` | `wavelet.HLH_glrlm_RunLengthNonUniformity` | 10245.5239331547 | 10245.5239331547 | 4.91e-11 |
| `opal3` | `original_firstorder_Energy` | 1186055557.30657 | 1186055557.30657 | 9.54e-07 |
| `opal3` | `original_glrlm_RunLengthNonUniformity` | 14466.9012668664 | 14466.9012668664 | 1.82e-11 |
| `opal3` | `original_shape_Compactness1` | 0.0263166107584965 | 0.0263166107584965 | 4.86e-17 |
| `opal3` | `wavelet.HLH_glrlm_RunLengthNonUniformity` | 11379.0070861031 | 11379.0070861031 | 7.28e-12 |

Maximum absolute difference: `9.54e-07`. Maximum relative difference:
`4.79e-15`.

Clinical metadata checks:

| metric | `opal1` | `opal2` | `opal3` |
|---|---:|---:|---:|
| mean `survival_time_days` | 1000.6197 | 976.9650 | 989.0803 |
| mean `os_2yr_alive` | 0.4184397 | 0.4055944 | 0.3823529 |

Federated GLM:

- Formula: `os_2yr_alive ~ original_firstorder_Energy + original_shape_Compactness1 + original_glrlm_RunLengthNonUniformity + wavelet.HLH_glrlm_RunLengthNonUniformity + age + gender_male`
- `num.valid.studies = 3`
- `<new.glm.obj>` was created and validated in all data sources.

Fixed-effect pooled estimates from `ds.glmSLMA()`:

| term | pooled.FE | se.FE |
|---|---:|---:|
| `(Intercept)` | 1.416178e-01 | 9.263942e-01 |
| `original_firstorder_Energy` | -8.452579e-11 | 1.228317e-10 |
| `original_shape_Compactness1` | 2.383309e+01 | 2.154354e+01 |
| `original_glrlm_RunLengthNonUniformity` | 8.191498e-05 | 5.991988e-05 |
| `wavelet.HLH_glrlm_RunLengthNonUniformity` | -1.184013e-04 | 7.716003e-05 |
| `age` | -9.693862e-03 | 1.150634e-02 |
| `gender_male` | -1.464250e-01 | 2.446642e-01 |

Notes:

- `process_collection()` status applies DataSHIELD metadata bucketing; the
  bucketed per-site total is `128`, while `ds.dim("rad")` and the local study
  manifest show the exact engineering counts above.
- Admin job listing/cancellation was enabled through the demo admin key and
  verified separately: a wrong key was rejected on all three Opals, while the
  configured key could list imaging jobs.
