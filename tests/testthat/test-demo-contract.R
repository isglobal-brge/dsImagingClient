.demo_path <- function(name) {
  source_path <- testthat::test_path("..", "..", "inst", "demos", name)
  if (dir.exists(source_path)) {
    return(normalizePath(source_path, mustWork = TRUE))
  }
  system.file("demos", name, package = "dsImagingClient")
}

test_that("validation demo publishes atomically with a patient contract", {
  demo_dir <- .demo_path("imaging_demo_validation")
  runner <- readLines(
    file.path(demo_dir, "run_imaging_demo_validation.R"), warn = FALSE)
  preparation <- readLines(
    file.path(demo_dir, "prepare_imaging_demo.py"), warn = FALSE)

  expect_false(any(grepl("--no-atomic", runner, fixed = TRUE)))
  expect_true(any(grepl(
    '"--privacy-unit-column", "patient_id"', runner, fixed = TRUE)))
  expect_true(any(grepl('"patient_id":', preparation, fixed = TRUE)))
})

test_that("LUNG1 demo separates publication from secret-free Resource handoff", {
  demo_dir <- .demo_path("lung1_federated_study")
  runner <- paste(readLines(
    file.path(demo_dir, "run_lung1_datashield.R"), warn = FALSE),
    collapse = "\n")
  readme <- paste(readLines(file.path(demo_dir, "README.md"), warn = FALSE),
                  collapse = "\n")
  expect_match(runner, '"dataset", "publish", row$dataset, source_dir',
               fixed = TRUE)
  expect_match(runner, '"dataset", "resource-plan", row$dataset',
               fixed = TRUE)
  expect_match(runner, 'c("opal", "armadillo")', fixed = TRUE)
  expect_match(runner, 'csv_env("LUNG1_ARMADILLO_URLS")', fixed = TRUE)
  expect_match(runner, "anyDuplicated(armadillo_url_keys)", fixed = TRUE)
  expect_match(runner, 'if (publish) "TRUE" else "FALSE"', fixed = TRUE)
  expect_match(readme, "resource-plans/opal/", fixed = TRUE)
  expect_match(readme, "resource-plans/armadillo/", fixed = TRUE)

  retired_or_secret_options <- c(
    "--access-key", "--secret-key", "--opal-url", "--opal-user",
    "--opal-password", "--opal-project", "--opal-resource",
    "--opal-replace", "--opal-insecure"
  )
  expect_false(any(vapply(
    retired_or_secret_options, grepl, logical(1), x = runner, fixed = TRUE)))
  expect_false(grepl("admin123|minioadmin", runner))
})

test_that("LUNG1 linked acceptance keeps clinical data outside the store", {
  demo_dir <- .demo_path("lung1_federated_study")
  runner <- paste(readLines(
    file.path(demo_dir, "run_lung1_linked_dslite.R"), warn = FALSE),
    collapse = "\n")
  preparation <- paste(readLines(
    file.path(demo_dir, "prepare_lung1_study.py"), warn = FALSE),
    collapse = "\n")
  readme <- paste(readLines(file.path(demo_dir, "README.md"), warn = FALSE),
                  collapse = "\n")
  evidence <- jsonlite::fromJSON(file.path(
    demo_dir, "LINKED_DSLITE_EVIDENCE.json"), simplifyVector = FALSE)
  evidence_fields <- c(
    "schema_version", "validated_on", "demo", "scope", "public_dataset",
    "site", "cohort_size", "imaging_metadata_columns",
    "clinical_table_separate", "radiomics_profile", "radiomics_published",
    "opaque_feature_view", "privacy_unit", "minimum_privacy_units",
    "dp_epsilon_per_training", "dp_delta_per_training", "model", "rounds",
    "model_artifact_available", "pass")

  expect_true(file.exists(file.path(demo_dir, "aerts_signature_v1.yaml")))
  expect_match(preparation,
               'clinical[["age", "gender_male", "os_2yr_alive"]]',
               fixed = TRUE)
  expect_match(preparation, 'site_dir / "clinical.csv"', fixed = TRUE)
  expect_match(preparation, 'site_dir / "imaging_metadata.csv"', fixed = TRUE)
  expect_match(
    preparation,
    'structural_metadata.to_csv(site_dir / "metadata.csv", index=False)',
    fixed = TRUE)
  expect_match(runner, "main <- function()", fixed = TRUE)
  expect_match(
    runner, 'imaging_metadata_path <- file.path(site_dir, "metadata.csv")',
    fixed = TRUE)
  expect_match(runner, "dsimaging.registry_path = registry_path", fixed = TRUE)
  expect_match(runner, 'clinical_id_col = "patient_id"', fixed = TRUE)
  expect_match(runner, "ds.imaging.radiomics.process_collection", fixed = TRUE)
  expect_match(runner, '!identical(radiomics$state, "ACTIVE")', fixed = TRUE)
  expect_match(runner, "ds.imaging.feature_view(", fixed = TRUE)
  expect_match(runner, "ds.flower.fit(", fixed = TRUE)
  expect_match(runner, "ds.imaging.feature_view.destroy", fixed = TRUE)
  expect_match(runner, 'cohort_size = "not released by the workflow"',
               fixed = TRUE)
  expect_match(runner, "dsflower.min_train_rows = 10L", fixed = TRUE)
  expect_false(grepl("--metadata", readme, fixed = TRUE))
  expect_true(isTRUE(evidence$pass))
  expect_match(evidence$validated_on, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
  expect_identical(evidence$privacy_unit, "patient")
  expect_identical(evidence$minimum_privacy_units, 10L)
  expect_identical(
    evidence$scope,
    "engineering systems demonstration; not clinical validation")
  expect_setequal(names(evidence), evidence_fields)
  expect_false(grepl(
    "s3://|asset_|gen_|imgf_|LUNG1-[0-9]+|/(tmp|Users|var)/",
    paste(unlist(evidence, use.names = FALSE), collapse = " ")))
  expect_false(grepl("admin123|minioadmin", runner))
})
