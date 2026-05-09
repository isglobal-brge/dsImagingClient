# Current Results

Run date: 2026-05-09

Dataset: TCIA NSCLC-Radiomics/LUNG1, 9 real patients, `GTV-1` RTSTRUCT masks,
partitioned by stable patient hash into 3 simulated sites.

Published collection assets:

- `opal1` / `lung1_site_a`: `asset_20260509_092711_b7545af7`
- `opal2` / `lung1_site_b`: `asset_20260509_093039_f9f914dd`
- `opal3` / `lung1_site_c`: `asset_20260509_093620_cd33748d`

DataSHIELD loaded dimensions:

- `opal1`: `3 x 35`
- `opal2`: `3 x 35`
- `opal3`: `3 x 35`
- combined: `9 x 35`

Note: this observed asset was generated before tightening `selected_features`
normalisation in the final code, so it contains the full Aerts-profile
PyRadiomics output plus metadata. Fresh runs with the final code filter runner
output to the requested selected features.

Federated feature means matched the central PyRadiomics baseline:

| server | feature | federated | central | abs_diff |
|---|---|---:|---:|---:|
| opal1 | original_firstorder_Energy | 808982115 | 808982115 | 3.58e-07 |
| opal1 | original_shape_Compactness1 | 0.02808881 | 0.02808881 | 4.51e-17 |
| opal1 | original_glrlm_RunLengthNonUniformity | 7370.775 | 7370.775 | 0 |
| opal1 | wavelet.HLH_glrlm_RunLengthNonUniformity | 6257.093 | 6257.093 | 9.09e-13 |
| opal2 | original_firstorder_Energy | 931587356 | 931587356 | 3.58e-07 |
| opal2 | original_shape_Compactness1 | 0.01911389 | 0.01911389 | 2.08e-17 |
| opal2 | original_glrlm_RunLengthNonUniformity | 15614.579 | 15614.579 | 2.00e-11 |
| opal2 | wavelet.HLH_glrlm_RunLengthNonUniformity | 13377.942 | 13377.942 | 2.91e-11 |
| opal3 | original_firstorder_Energy | 4002561297 | 4002561297 | 0 |
| opal3 | original_shape_Compactness1 | 0.02421538 | 0.02421538 | 3.47e-17 |
| opal3 | original_glrlm_RunLengthNonUniformity | 37924.683 | 37924.683 | 2.91e-11 |
| opal3 | wavelet.HLH_glrlm_RunLengthNonUniformity | 28100.251 | 28100.251 | 2.91e-11 |

Clinical metadata was loaded with the radiomics asset:

- mean `survival_time_days`: opal1 `156.67`, opal2 `867.67`, opal3 `820.33`
- mean `os_2yr_alive`: opal1 `0.00`, opal2 `0.33`, opal3 `0.33`

Container OOM status after the run:

- `opal1-rock`: `OOMKilled=false`
- `opal2-rock`: `OOMKilled=false`
- `opal3-rock`: `OOMKilled=false`
