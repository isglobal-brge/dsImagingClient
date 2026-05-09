# Federated LUNG1 radiomics study

This article documents the full public LUNG1/NSCLC-Radiomics
demonstration for `dsImagingClient`. The workflow uses CT images and
RTSTRUCT `GTV-1` tumour masks from TCIA, publishes three simulated
DataSHIELD sites through `dsimaging-store`, runs Aerts-signature
PyRadiomics extraction through `dsImaging` and `dsHPC`, and compares the
federated summaries with a central PyRadiomics baseline over the same
patients.

The default pkgdown build renders the validated results below without
launching jobs. To execute the live demo while rendering this article,
set `DSIMAGINGCLIENT_RUN_LUNG1_VIGNETTE=true` and point `LUNG1_WORKDIR`
at a prepared LUNG1 workspace.

## Running The Demo

The preparation and execution scripts are installed with the package
under `inst/demos/lung1_federated_study`.

``` r

demo_dir <- system.file("demos", "lung1_federated_study",
                        package = "dsImagingClient")
if (!nzchar(demo_dir)) {
  demo_dir <- normalizePath(file.path("..", "inst", "demos",
                                     "lung1_federated_study"),
                            mustWork = FALSE)
}
prepare_script <- file.path(demo_dir, "prepare_lung1_study.py")
run_script <- file.path(demo_dir, "run_lung1_datashield.R")
c(prepare_script = prepare_script, run_script = run_script)
#>                                                                                                                                                     prepare_script 
#> "/private/var/folders/tn/qg45ss_91k375mrb66zqhx_m0000gn/T/RtmpWKHQe1/temp_libpath1224216675c04/dsImagingClient/demos/lung1_federated_study/prepare_lung1_study.py" 
#>                                                                                                                                                         run_script 
#> "/private/var/folders/tn/qg45ss_91k375mrb66zqhx_m0000gn/T/RtmpWKHQe1/temp_libpath1224216675c04/dsImagingClient/demos/lung1_federated_study/run_lung1_datashield.R"
```

Prepare the full public cohort:

``` bash
python3 inst/demos/lung1_federated_study/prepare_lung1_study.py \
  --workdir /tmp/dsimaging_lung1_full \
  --all-patients
```

Run or resume the federated DataSHIELD pass:

``` bash
LUNG1_WORKDIR=/tmp/dsimaging_lung1_full \
LUNG1_DATASET_PREFIX=lung1_full_site \
LUNG1_OPAL_RESOURCE=lung1_full_study \
LUNG1_PUBLISH=FALSE \
LUNG1_RUN_JOBS=FALSE \
LUNG1_TIMEOUT=0 \
LUNG1_RUN_GLM=TRUE \
OPAL_USER=administrator \
OPAL_PASSWORD=admin123 \
Rscript inst/demos/lung1_federated_study/run_lung1_datashield.R
```

``` r

demo_env <- c(
  paste0("LUNG1_WORKDIR=", Sys.getenv("LUNG1_WORKDIR",
                                      "/tmp/dsimaging_lung1_full")),
  paste0("LUNG1_DATASET_PREFIX=", Sys.getenv("LUNG1_DATASET_PREFIX",
                                             "lung1_full_site")),
  paste0("LUNG1_OPAL_RESOURCE=", Sys.getenv("LUNG1_OPAL_RESOURCE",
                                            "lung1_full_study")),
  paste0("LUNG1_PUBLISH=", Sys.getenv("LUNG1_PUBLISH", "FALSE")),
  paste0("LUNG1_RUN_JOBS=", Sys.getenv("LUNG1_RUN_JOBS", "FALSE")),
  paste0("LUNG1_TIMEOUT=", Sys.getenv("LUNG1_TIMEOUT", "0")),
  paste0("LUNG1_RUN_GLM=", Sys.getenv("LUNG1_RUN_GLM", "TRUE")),
  paste0("OPAL_USER=", Sys.getenv("OPAL_USER", "administrator")),
  paste0("OPAL_PASSWORD=", Sys.getenv("OPAL_PASSWORD", "admin123"))
)
status <- system2("Rscript", run_script, env = demo_env)
if (!identical(status, 0L)) {
  stop("LUNG1 demo failed with exit status ", status, call. = FALSE)
}
```

## Validated Cohort

The final validation pass used every public LUNG1 patient that passed CT
and `GTV-1` mask conversion: `422` patients split across three sites by
stable patient hash.

``` r

site_counts <- data.frame(
  site = c("site_a", "site_b", "site_c"),
  dataset = c("lung1_full_site_a", "lung1_full_site_b", "lung1_full_site_c"),
  images = c(142L, 143L, 137L),
  masks = c(142L, 143L, 137L),
  metadata_rows = c(142L, 143L, 137L)
)
knitr::kable(site_counts)
```

| site   | dataset           | images | masks | metadata_rows |
|:-------|:------------------|-------:|------:|--------------:|
| site_a | lung1_full_site_a |    142 |   142 |           142 |
| site_b | lung1_full_site_b |    143 |   143 |           143 |
| site_c | lung1_full_site_c |    137 |   137 |           137 |

Published collection assets:

``` r

assets <- data.frame(
  opal = c("opal1", "opal2", "opal3"),
  dataset = c("lung1_full_site_a", "lung1_full_site_b", "lung1_full_site_c"),
  generation = c("gen_20260509_152105_9e354de9",
                 "gen_20260509_152108_8cf5c55f",
                 "gen_20260509_152110_b82b5785"),
  asset = c("asset_20260509_165902_42b9b1a5",
            "asset_20260509_170056_0bfdbf8e",
            "asset_20260509_170057_9a3db2ab")
)
knitr::kable(assets)
```

| opal | dataset | generation | asset |
|:---|:---|:---|:---|
| opal1 | lung1_full_site_a | gen_20260509_152105_9e354de9 | asset_20260509_165902_42b9b1a5 |
| opal2 | lung1_full_site_b | gen_20260509_152108_8cf5c55f | asset_20260509_170056_0bfdbf8e |
| opal3 | lung1_full_site_c | gen_20260509_152110_b82b5785 | asset_20260509_170057_9a3db2ab |

After
`ds.imaging.radiomics.load_features(..., include_metadata = TRUE)`, the
server-side analysis tables had these dimensions:

``` r

loaded_dims <- data.frame(
  source = c("opal1", "opal2", "opal3", "combined"),
  dimensions = c("142 x 20", "143 x 20", "137 x 20", "422 x 20")
)
knitr::kable(loaded_dims)
```

| source   | dimensions |
|:---------|:-----------|
| opal1    | 142 x 20   |
| opal2    | 143 x 20   |
| opal3    | 137 x 20   |
| combined | 422 x 20   |

## Federated Versus Central Radiomics

The published collection parquet schema is constrained by the Aerts
signature profile to `sample_id` plus four radiomics features. The
remaining loaded columns are clinical metadata joined by `sample_id`.

``` r

knitr::kable(
  comparison[, c("server", "feature", "federated", "central",
                 "abs_diff_fmt", "rel_diff_fmt")],
  col.names = c("server", "feature", "federated mean", "central mean",
                "abs diff", "rel diff"),
  digits = 12
)
```

| server | feature | federated mean | central mean | abs diff | rel diff |
|:---|:---|---:|---:|:---|:---|
| opal1 | original_firstorder_Energy | 9.127437e+08 | 9.127437e+08 | 5.960e-07 | 6.530e-16 |
| opal1 | original_glrlm_RunLengthNonUniformity | 1.243088e+04 | 1.243088e+04 | 4.366e-11 | 3.512e-15 |
| opal1 | original_shape_Compactness1 | 2.588479e-02 | 2.588479e-02 | 2.429e-17 | 9.382e-16 |
| opal1 | wavelet.HLH_glrlm_RunLengthNonUniformity | 9.307556e+03 | 9.307556e+03 | 1.819e-12 | 1.954e-16 |
| opal2 | original_firstorder_Energy | 9.245573e+08 | 9.245573e+08 | 1.192e-07 | 1.289e-16 |
| opal2 | original_glrlm_RunLengthNonUniformity | 1.315188e+04 | 1.315188e+04 | 1.637e-11 | 1.245e-15 |
| opal2 | original_shape_Compactness1 | 2.682938e-02 | 2.682938e-02 | 1.388e-17 | 5.173e-16 |
| opal2 | wavelet.HLH_glrlm_RunLengthNonUniformity | 1.024552e+04 | 1.024552e+04 | 4.911e-11 | 4.794e-15 |
| opal3 | original_firstorder_Energy | 1.186056e+09 | 1.186056e+09 | 9.537e-07 | 8.041e-16 |
| opal3 | original_glrlm_RunLengthNonUniformity | 1.446690e+04 | 1.446690e+04 | 1.819e-11 | 1.257e-15 |
| opal3 | original_shape_Compactness1 | 2.631661e-02 | 2.631661e-02 | 4.857e-17 | 1.846e-15 |
| opal3 | wavelet.HLH_glrlm_RunLengthNonUniformity | 1.137901e+04 | 1.137901e+04 | 7.276e-12 | 6.394e-16 |

Maximum absolute difference: 9.537e-07. Maximum relative difference:
4.794e-15.

## Clinical Metadata And Federated GLM

Clinical metadata were joined to the radiomics feature table on the
server side before analysis.

``` r

clinical <- data.frame(
  metric = c("mean survival_time_days", "mean os_2yr_alive"),
  opal1 = c(1000.6197, 0.4184397),
  opal2 = c(976.9650, 0.4055944),
  opal3 = c(989.0803, 0.3823529)
)
knitr::kable(clinical, digits = 7)
```

| metric                  |        opal1 |       opal2 |       opal3 |
|:------------------------|-------------:|------------:|------------:|
| mean survival_time_days | 1000.6197000 | 976.9650000 | 989.0803000 |
| mean os_2yr_alive       |    0.4184397 |   0.4055944 |   0.3823529 |

A federated `ds.glmSLMA()` model was fit with:

``` r

glm_formula <- os_2yr_alive ~ original_firstorder_Energy +
  original_shape_Compactness1 +
  original_glrlm_RunLengthNonUniformity +
  wavelet.HLH_glrlm_RunLengthNonUniformity +
  age + gender_male
glm_formula
#> os_2yr_alive ~ original_firstorder_Energy + original_shape_Compactness1 + 
#>     original_glrlm_RunLengthNonUniformity + wavelet.HLH_glrlm_RunLengthNonUniformity + 
#>     age + gender_male
```

The run produced `num.valid.studies = 3`; `<new.glm.obj>` was created
and validated in all data sources.

``` r

glm_fe <- data.frame(
  term = c("(Intercept)", "original_firstorder_Energy",
           "original_shape_Compactness1",
           "original_glrlm_RunLengthNonUniformity",
           "wavelet.HLH_glrlm_RunLengthNonUniformity",
           "age", "gender_male"),
  pooled.FE = c(1.416178e-01, -8.452579e-11, 2.383309e+01,
                8.191498e-05, -1.184013e-04, -9.693862e-03,
                -1.464250e-01),
  se.FE = c(9.263942e-01, 1.228317e-10, 2.154354e+01,
            5.991988e-05, 7.716003e-05, 1.150634e-02,
            2.446642e-01)
)
knitr::kable(glm_fe, digits = 6)
```

| term                                     | pooled.FE |     se.FE |
|:-----------------------------------------|----------:|----------:|
| (Intercept)                              |  0.141618 |  0.926394 |
| original_firstorder_Energy               |  0.000000 |  0.000000 |
| original_shape_Compactness1              | 23.833090 | 21.543540 |
| original_glrlm_RunLengthNonUniformity    |  0.000082 |  0.000060 |
| wavelet.HLH_glrlm_RunLengthNonUniformity | -0.000118 |  0.000077 |
| age                                      | -0.009694 |  0.011506 |
| gender_male                              | -0.146425 |  0.244664 |

## Operational Notes

- The full run is resumable. DICOM downloads, NIfTI/mask conversion,
  central PyRadiomics extraction, DataSHIELD job submission, and
  collection publishing can be resumed from the same `LUNG1_WORKDIR`.
- `process_collection()` reports disclosure-bucketed metadata, so its
  status may show `128` rather than exact per-site counts.
  `ds.dim("rad")` and the local manifest are the engineering checks for
  exact dimensions.
- Admin job listing and cancellation use `dshpc.admin_key` or
  `DSHPC_ADMIN_KEY`; wrong keys are rejected by all sites.
