test_that("validation demo publishes atomically with a patient contract", {
  demo_dir <- system.file(
    "demos", "imaging_demo_validation", package = "dsImagingClient")
  if (!nzchar(demo_dir)) {
    demo_dir <- normalizePath(testthat::test_path(
      "..", "..", "inst", "demos", "imaging_demo_validation"),
      mustWork = TRUE)
  }
  runner <- readLines(
    file.path(demo_dir, "run_imaging_demo_validation.R"), warn = FALSE)
  preparation <- readLines(
    file.path(demo_dir, "prepare_imaging_demo.py"), warn = FALSE)

  expect_false(any(grepl("--no-atomic", runner, fixed = TRUE)))
  expect_true(any(grepl(
    '"--privacy-unit-column", "patient_id"', runner, fixed = TRUE)))
  expect_true(any(grepl('"patient_id":', preparation, fixed = TRUE)))
})
