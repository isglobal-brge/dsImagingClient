test_that("summary uses handle-scoped metadata and catalog without job listing", {
  testthat::local_mocked_bindings(
    ds.imaging.metadata = function(conns, handle = "img") list(
      site = list(dataset_id = "study.images", modality = "ct")),
    ds.imaging.catalog = function(conns, dataset_id = NULL, kind = NULL,
                                  handle = "img") list(
      site = data.frame(
        asset_id = paste0("asset_", strrep("a", 32)),
        kind = "feature_table", modality = "ct")),
    ds.imaging.jobs = function(...) stop("retired job listing was called"),
    .package = "dsImagingClient"
  )

  output <- capture.output(
    result <- ds.imaging.summary(list(site = NULL), handle = "images"))

  expect_true(any(grepl("study.images", output, fixed = TRUE)))
  expect_true(any(grepl("Modality: ct", output, fixed = TRUE)))
  expect_named(result, c("metadata", "assets"))
  expect_false(any(grepl("job_", output, fixed = TRUE)))
})
