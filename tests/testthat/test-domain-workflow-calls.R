decode_workflow_request <- function(expr) {
  payload <- sub("^B64:", "", as.character(expr[[2L]]))
  payload <- chartr("-_", "+/", payload)
  padding <- (4L - nchar(payload) %% 4L) %% 4L
  payload <- paste0(payload, strrep("=", padding))
  jsonlite::fromJSON(rawToChar(jsonlite::base64_dec(payload)),
    simplifyVector = FALSE)
}

empty_test_symbols <- function(conns) {
  stats::setNames(lapply(names(conns), function(x) character()), names(conns))
}

test_that("radiomics extraction invokes the dsImaging domain method", {
  calls <- list()
  testthat::local_mocked_bindings(
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      calls[[length(calls) + 1L]] <<- list(symbol = symbol, expr = expr)
      for (host in names(conns)) success(host)
      invisible(TRUE)
    },
    datashield.symbols = empty_test_symbols,
    .package = "DSI"
  )

  res <- ds.imaging.radiomics.extract(list(server_1 = list()), "lung1",
    mask_asset = "gtv", profile = ds.imaging.radiomics.profile.demo_ct_firstorder(),
    symbol = "job_handle", handle = "study")

  expect_equal(res$method, "imagingProcessRadiomicsAssetDS")
  expect_equal(res$symbol, "job_handle")
  expect_equal(as.character(calls[[1]]$expr[[1]]), "imagingProcessRadiomicsAssetDS")
  expect_match(as.character(calls[[1]]$expr[[2]]), "^B64:")
  request <- decode_workflow_request(calls[[1]]$expr)
  expect_equal(request$handle, "study")
  expect_equal(request$dataset_id, "lung1")
  expect_null(request$visibility)
  expect_null(request$job_id)
})

test_that("segmentation and clinical workflows do not call dsHPCClient submit", {
  assign_calls <- list()
  testthat::local_mocked_bindings(
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      assign_calls[[length(assign_calls) + 1L]] <<- expr
      for (host in names(conns)) success(host)
      invisible(TRUE)
    },
    datashield.symbols = empty_test_symbols,
    .package = "DSI"
  )

  ds.imaging.segment(list(server_1 = list()), "lung1",
    segmenter = ds.imaging.segmenter.ct_lung_threshold(), symbol = "seg")
  qc <- ds.imaging.qc.metrics(list(server_1 = list()), "lung1",
    handle = "study")

  expect_equal(as.character(assign_calls[[1L]][[1L]]),
    "imagingProcessSegmentationCollectionDS")
  expect_equal(as.character(assign_calls[[2L]][[1L]]),
    "imagingProcessAssetWorkflowDS")
  expect_equal(decode_workflow_request(assign_calls[[1L]])$handle, "img")
  expect_equal(decode_workflow_request(assign_calls[[2L]])$handle, "study")
  expect_null(decode_workflow_request(assign_calls[[1L]])$visibility)
  expect_null(decode_workflow_request(assign_calls[[2L]])$visibility)
  clinical_request <- decode_workflow_request(assign_calls[[2L]])
  expect_false(any(c("label_tag", "asset_type", "publish_kind") %in%
    names(clinical_request)))
  expect_null(clinical_request$config$dataset_id)
  expect_null(decode_workflow_request(assign_calls[[1L]])$job_id)
  expect_null(decode_workflow_request(assign_calls[[2L]])$job_id)
  expect_equal(qc$handle, "study")
  expect_null(qc$job_id)
})

test_that("segment-and-extract uses its dedicated endpoint and image asset", {
  calls <- list()
  testthat::local_mocked_bindings(
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      calls[[length(calls) + 1L]] <<- list(symbol = symbol, expr = expr)
      for (host in names(conns)) success(host)
      invisible(TRUE)
    },
    datashield.symbols = empty_test_symbols,
    .package = "DSI"
  )

  result <- ds.imaging.radiomics.segment_and_extract(
    list(server_1 = list()), dataset_id = "lung1",
    image_asset = "registered_ct",
    segmenter = ds.imaging.segmenter.ct_lung_threshold(),
    timeout = 0, handle = "study", symbol = "seg_extract")

  expect_equal(result$method, "imagingProcessSegmentAndExtractDS")
  expect_equal(result$symbol, "seg_extract")
  expect_length(calls, 1L)
  expect_equal(as.character(calls[[1L]]$expr[[1L]]),
    "imagingProcessSegmentAndExtractDS")
  request <- decode_workflow_request(calls[[1L]]$expr)
  expect_equal(request$handle, "study")
  expect_equal(request$dataset_id, "lung1")
  expect_equal(request$image_asset, "registered_ct")
  expect_null(request$batch_size)
  expect_null(request$visibility)
})

test_that("DICOM and QC requests keep their closed collection contracts", {
  calls <- list()
  testthat::local_mocked_bindings(
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      calls[[length(calls) + 1L]] <<- expr
      for (host in names(conns)) success(host)
      invisible(TRUE)
    },
    datashield.symbols = empty_test_symbols,
    .package = "DSI"
  )
  conns <- list(server_1 = list())

  ds.imaging.dicom.convert(conns, handle = "study")
  expect_warning(
    ds.imaging.qc.visuals(conns, max_images = 1L, handle = "study"),
    "complete admitted collection", fixed = TRUE)

  dicom <- decode_workflow_request(calls[[1L]])
  qc <- decode_workflow_request(calls[[2L]])
  expect_equal(dicom$config$converter, "simpleitk")
  expect_equal(dicom$handle, "study")
  expect_null(qc$config$max_images)
  expect_null(qc$config$anonymize_names)
  expect_equal(qc$handle, "study")

  before <- length(calls)
  expect_error(ds.imaging.qc.visuals(conns, anonymize_names = FALSE),
    "must remain pseudonymized", fixed = TRUE)
  expect_length(calls, before)
})

test_that("unsupported patient-mapping workflows fail before transport", {
  testthat::local_mocked_bindings(
    datashield.assign.expr = function(...) {
      fail("An unsupported request reached DataSHIELD")
    },
    .package = "DSI"
  )
  conns <- list(server_1 = list())
  expect_error(ds.imaging.rt.convert(conns), "exact patient-sample mapping")
  expect_error(ds.imaging.rt.dose(conns), "exact patient-sample mapping")
  expect_error(ds.imaging.wsi.tile(conns), "exact patient-sample mapping")
  expect_error(ds.imaging.segmenter.monai_bundle("bundle"),
    "exact per-sample contract")
})

test_that("asset loading is scoped to the initialized handle", {
  assigned <- NULL
  testthat::local_mocked_bindings(
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      assigned <<- list(symbol = symbol, expr = expr)
      success(names(conns)[[1L]])
      invisible(TRUE)
    },
    datashield.symbols = empty_test_symbols,
    .package = "DSI"
  )
  ds.imaging.radiomics.load_features(list(server_1 = list()), "lung1",
    "radiomics", columns = c("mean", "energy"), handle = "study")
  expect_equal(assigned$symbol, "radiomics")
  expect_equal(as.character(assigned$expr[[1L]]), "imagingLoadAssetDS")
  expect_equal(assigned$expr[[2L]], "study")
  expect_equal(assigned$expr[[3L]], "radiomics")
  expect_identical(
    assigned$expr[[4L]],
    dsImagingClient:::.ds_encode(c("mean", "energy")))
})

test_that("collection workflow is assigned once and carries no discovery data", {
  calls <- list()
  testthat::local_mocked_bindings(
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      calls[[length(calls) + 1L]] <<- list(symbol = symbol, expr = expr)
      for (host in names(conns)) success(host)
      invisible(TRUE)
    },
    datashield.symbols = empty_test_symbols,
    .package = "DSI"
  )

  result <- ds.imaging.radiomics.process_collection(
    list(server_1 = list(), server_2 = list()),
    segmenter = ds.imaging.segmenter.existing_mask("masks"),
    timeout = 0, handle = "study", symbol = "collection_job")

  expect_length(calls, 1L)
  expect_equal(calls[[1L]]$symbol, "collection_job")
  expect_equal(as.character(calls[[1L]]$expr[[1L]]),
    "imagingProcessRadiomicsCollectionDS")
  request <- decode_workflow_request(calls[[1L]]$expr)
  expect_equal(request$handle, "study")
  expect_null(request$dataset_id)
  expect_null(request$visibility)
  expect_false(any(c("pending_ids", "fingerprints", "content_hashes", "job_id") %in%
    names(request)))
  expect_equal(result$symbol, "collection_job")
})

test_that("analytical clients reject unsupported visibility before a server call", {
  testthat::local_mocked_bindings(
    datashield.assign.expr = function(...) {
      fail("A global analytical request reached DataSHIELD")
    },
    .package = "DSI"
  )
  conns <- list(server_1 = list())

  expect_error(ds.imaging.radiomics.extract(conns, "lung1",
    mask_asset = "masks", visibility = "raw_public"),
    "shared validated outputs", fixed = TRUE)
  expect_error(ds.imaging.segment(conns, "lung1",
    segmenter = ds.imaging.segmenter.ct_lung_threshold(),
    visibility = "raw_public"), "shared validated outputs", fixed = TRUE)
  expect_error(ds.imaging.radiomics.process_collection(conns,
    segmenter = ds.imaging.segmenter.existing_mask("masks"),
    timeout = 0, visibility = "raw_public"),
    "shared validated outputs", fixed = TRUE)
  expect_error(ds.imaging.qc.metrics(conns, "lung1",
    visibility = "raw_public"), "shared validated outputs", fixed = TRUE)
})

test_that("collection control aggregates use the workflow symbol", {
  calls <- list()
  testthat::local_mocked_bindings(
    datashield.aggregate = function(conns, expr) {
      calls[[length(calls) + 1L]] <<- expr
      method <- as.character(expr[[1L]])
      if (identical(method, "imagingCollectionPublishDS")) {
        return(list(state = "ACTIVE", asset_id = paste0("asset_", strrep("a", 32)),
          generation_id = "hidden"))
      }
      list(state = "ACTIVE", is_done = TRUE, completed = 12L,
        pending_ids = "hidden")
    },
    .package = "DSI"
  )
  conns <- list(server_1 = list())

  status <- ds.imaging.radiomics.collection_status(conns, "collection_job")
  recovered <- ds.imaging.radiomics.collection_recover(conns, "collection_job")
  published <- ds.imaging.radiomics.collection_publish(conns, "collection_job")

  expect_equal(vapply(calls, function(x) as.character(x[[1L]]), character(1)),
    c("imagingCollectionStatusDS", "imagingCollectionRecoverDS",
      "imagingCollectionPublishDS"))
  expect_true(all(vapply(calls, function(x) identical(x[[2L]], "collection_job"),
    logical(1))))
  expect_length(calls[[3L]], 2L)
  expect_setequal(names(status), c("state", "is_done"))
  expect_setequal(names(recovered), c("state", "is_done"))
  expect_setequal(names(published), c("state", "asset_id"))
})

test_that("collection responses fail closed on invalid public fields", {
  expect_error(dsImagingClient:::.collection_project(
    list(node = list(state = "/private/patient-7", is_done = TRUE)),
    c("state", "is_done", "asset_id")),
    "public schema", fixed = TRUE)
  expect_error(dsImagingClient:::.collection_project(
    list(node = list(state = "ACTIVE", is_done = "yes")),
    c("state", "is_done", "asset_id")),
    "public schema", fixed = TRUE)
  expect_error(dsImagingClient:::.collection_project(
    list(node = list(state = "PUBLISHED", is_done = TRUE,
                     asset_id = "/private/patient-7")),
    c("state", "is_done", "asset_id")),
    "public schema", fixed = TRUE)
})

test_that("collection cancellation uses the opaque workflow symbol", {
  call_expr <- NULL
  testthat::local_mocked_bindings(
    datashield.aggregate = function(conns, expr) {
      call_expr <<- expr
      list(state = "CANCELLED")
    },
    .package = "DSI"
  )

  result <- ds.imaging.radiomics.collection_cancel(
    list(server_1 = list()), "collection_job", "operator-secret")

  expect_equal(as.character(call_expr[[1L]]),
    "imagingRadiomicsCancelCollectionDS")
  expect_identical(call_expr[[2L]], "collection_job")
  expect_match(as.character(call_expr[[3L]]), "^B64:")
  expect_equal(result$state, "CANCELLED")
})

test_that("retired discovery helpers fail before a server call", {
  testthat::local_mocked_bindings(
    datashield.aggregate = function(...) {
      fail("A retired helper attempted a DataSHIELD call")
    },
    .package = "DSI"
  )

  expect_error(ds.imaging.asset(list(), "asset"), "no longer available")
  expect_error(ds.imaging.aliases(list(), "dataset"), "no longer available")
  expect_error(ds.imaging.lineage(list(), "asset"), "no longer available")
  expect_error(ds.imaging.check_exists(list(), "dataset"),
    "no longer available")
  expect_error(ds.imaging.labels(list()), "no longer available")
})

test_that("collection polling needs only sanitized state fields", {
  testthat::local_mocked_bindings(
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      for (host in names(conns)) success(host)
      invisible(TRUE)
    },
    datashield.symbols = empty_test_symbols,
    datashield.aggregate = function(conns, expr) {
      method <- as.character(expr[[1L]])
      if (identical(method, "imagingCollectionStatusDS")) {
        return(list(state = "ACTIVE", is_done = TRUE))
      }
      list(state = "ACTIVE", asset_id = paste0("asset_", strrep("a", 32)))
    },
    .package = "DSI"
  )

  result <- ds.imaging.radiomics.process_collection(
    list(server_1 = list()),
    segmenter = ds.imaging.segmenter.existing_mask("masks"),
    timeout = 1, poll_interval = 0, symbol = "collection_job")

  expect_equal(result$state, "ACTIVE")
  expect_equal(result$asset_id, paste0("asset_", strrep("a", 32)))
})

test_that("collection polling never publishes when one status call fails", {
  methods <- character()
  testthat::local_mocked_bindings(
    datashield.assign.expr = function(conns, symbol, expr, success, ...) {
      for (host in names(conns)) success(host)
      invisible(TRUE)
    },
    datashield.symbols = empty_test_symbols,
    datashield.aggregate = function(conns, expr) {
      methods <<- c(methods, as.character(expr[[1L]]))
      if (identical(names(conns), "server_2")) stop("unavailable")
      list(state = "ACTIVE", is_done = TRUE)
    },
    .package = "DSI"
  )

  expect_warning(
    expect_error(
      ds.imaging.radiomics.process_collection(
        list(server_1 = list(), server_2 = list()),
        segmenter = ds.imaging.segmenter.existing_mask("masks"),
        timeout = 1, poll_interval = 0, symbol = "collection_job"),
      "publication was not attempted", fixed = TRUE),
    "server_2", fixed = TRUE)
  expect_false("imagingCollectionPublishDS" %in% methods)
})

test_that("catalog is scoped to the initialized handle", {
  call_expr <- NULL
  testthat::local_mocked_bindings(
    datashield.aggregate = function(conns, expr) {
      call_expr <<- expr
      data.frame()
    },
    .package = "DSI"
  )

  ds.imaging.catalog(list(server_1 = list()), dataset_id = "legacy",
    kind = "radiomics_collection", handle = "study")

  expect_equal(as.character(call_expr[[1L]]), "imagingAssetCatalogDS")
  expect_equal(call_expr[[2L]], "study")
  expect_equal(call_expr[[3L]], "radiomics_collection")

  ds.imaging.catalog(list(server_1 = list()), handle = "study")
  expect_length(call_expr, 3L)
  expect_null(call_expr[[3L]])
})

test_that("client workflow sources no longer reference dsHPCClient submission helpers", {
  ns <- asNamespace("dsImagingClient")
  objects <- mget(ls(ns, all.names = TRUE), envir = ns, inherits = FALSE)
  functions <- objects[vapply(objects, is.function, logical(1))]
  src <- paste(vapply(functions, function(fun) {
    paste(deparse(fun), collapse = "\n")
  }, character(1)), collapse = "\n")
  expect_false(grepl("dsHPCClient::ds\\.hpc\\.submit", src))
  expect_false(grepl("dsHPCClient::ds_job", src))
  expect_false(grepl("dsHPCClient::ds_step_", src))
  forbidden <- c(
    "imagingRadiomicsScanCollectionDS",
    "imagingRadiomicsSubmitBatchDS",
    "imagingRadiomicsCollectionStatusDS",
    "imagingRadiomicsPublishCollectionDS",
    "imagingListDatasetsDS",
    "contentHashDS",
    "allow_partial",
    "job_id"
  )
  expect_false(any(vapply(forbidden, grepl, logical(1), x = src, fixed = TRUE)))

  demo_dir <- system.file("demos", package = "dsImagingClient")
  expect_true(nzchar(demo_dir))
  demo_files <- list.files(demo_dir, full.names = TRUE, recursive = TRUE,
    pattern = "\\.R$")
  demo_src <- paste(vapply(demo_files, function(path) {
    paste(readLines(path, warn = FALSE), collapse = "\n")
  }, character(1)), collapse = "\n")
  expect_false(grepl("hpcSubmitDS|hpcLoadOutputDS", demo_src))
  expect_false(grepl("ds\\.hpc\\.(submit|load)", demo_src))
  expect_false(grepl("\\$job_id", demo_src))

  evidence_path <- system.file("extdata",
    "imaging_demo_validation_summary.json", package = "dsImagingClient")
  expect_true(nzchar(evidence_path))
  evidence <- jsonlite::read_json(evidence_path, simplifyVector = FALSE)
  public_evidence <- jsonlite::toJSON(evidence, auto_unbox = TRUE)
  expect_identical(evidence$artifact_type, "sanitized_demo_fixture")
  expect_false(grepl("job_id|created_by_job|path_or_root|/srv/dshpc|job_",
    public_evidence))
})
