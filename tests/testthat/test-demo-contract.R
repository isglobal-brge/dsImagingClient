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
