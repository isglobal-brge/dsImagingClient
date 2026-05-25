test_that("radiomics extraction invokes the dsImaging domain method", {
  calls <- list()
  testthat::local_mocked_bindings(
    datashield.assign.expr = function(conns, symbol, expr) {
      calls[[length(calls) + 1L]] <<- list(symbol = symbol, expr = expr)
      invisible(TRUE)
    },
    .package = "DSI"
  )

  res <- ds.imaging.radiomics.extract(list(server_1 = list()), "lung1",
    mask_asset = "gtv", profile = ds.imaging.radiomics.profile.demo_ct_firstorder(),
    symbol = "job_handle")

  expect_equal(res$method, "imagingProcessRadiomicsAssetDS")
  expect_equal(res$symbol, "job_handle")
  expect_equal(as.character(calls[[1]]$expr[[1]]), "imagingProcessRadiomicsAssetDS")
  expect_match(as.character(calls[[1]]$expr[[2]]), "^B64:")
})

test_that("segmentation and clinical workflows do not call dsHPCClient submit", {
  assign_methods <- character(0)
  testthat::local_mocked_bindings(
    datashield.assign.expr = function(conns, symbol, expr) {
      assign_methods <<- c(assign_methods, as.character(expr[[1]]))
      invisible(TRUE)
    },
    .package = "DSI"
  )

  ds.imaging.segment(list(server_1 = list()), "lung1",
    segmenter = ds.imaging.segmenter.ct_lung_threshold(), symbol = "seg")
  ds.imaging.qc.metrics(list(server_1 = list()), "lung1")

  expect_equal(assign_methods[[1]], "imagingProcessSegmentationCollectionDS")
  expect_equal(assign_methods[[2]], "imagingProcessAssetWorkflowDS")
})

test_that("radiomics feature loading uses the domain load method", {
  method <- NULL
  testthat::local_mocked_bindings(
    datashield.assign.expr = function(conns, symbol, expr) {
      method <<- as.character(expr[[1]])
      invisible(TRUE)
    },
    .package = "DSI"
  )
  ds.imaging.radiomics.load_features(list(server_1 = list()), "lung1", "radiomics")
  expect_equal(method, "imagingLoadRadiomicsFeaturesDS")
})

test_that("client workflow sources no longer reference dsHPCClient submission helpers", {
  files <- list.files(test_path("../../R"), full.names = TRUE, pattern = "\\.R$")
  src <- paste(vapply(files, function(path) paste(readLines(path, warn = FALSE),
    collapse = "\n"), character(1)), collapse = "\n")
  expect_false(grepl("dsHPCClient::ds\\.hpc\\.submit", src))
  expect_false(grepl("dsHPCClient::ds_job", src))
  expect_false(grepl("dsHPCClient::ds_step_", src))
})
