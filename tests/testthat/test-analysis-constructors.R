test_that("imaging radiomics profiles and segmenters are built", {
  profile <- ds.imaging.radiomics.profile.demo_ct_firstorder()
  expect_equal(profile$name, "demo_ct_firstorder_v1")
  expect_false(profile$force2D)
  expect_equal(profile$feature_classes, "firstorder")

  segmenter <- ds.imaging.segmenter.ct_lung_threshold(
    threshold = -400,
    max_components = 3,
    min_voxels = 200)
  expect_equal(segmenter$provider, "ct_lung_threshold")
  expect_equal(segmenter$threshold, -400)
  expect_equal(segmenter$max_components, 3L)
})

test_that("legacy radiomics aliases are not exported", {
  exports <- getNamespaceExports("dsImagingClient")
  expect_false("ds.radiomics.profile.aerts_signature" %in% exports)
  expect_false("ds.segmenter.lungmask" %in% exports)
})

test_that("imaging dataset wrappers default to the canonical handle", {
  wrappers <- list(
    ds.imaging.assets,
    ds.imaging.metadata,
    ds.imaging.validate,
    ds.imaging.catalog,
    ds.imaging.radiomics.features,
    ds.imaging.masks,
    ds.imaging.load_asset,
    ds.imaging.radiomics.load_features,
    ds.imaging.radiomics.process_collection,
    ds.imaging.radiomics.segment_and_extract,
    ds.imaging.radiomics.extract,
    ds.imaging.segment,
    ds.imaging.dicom.convert,
    ds.imaging.preprocess,
    ds.imaging.mask.operation,
    ds.imaging.qc.metrics,
    ds.imaging.rt.convert,
    ds.imaging.rt.dose,
    ds.imaging.qc.visuals,
    ds.imaging.spatial.process,
    ds.imaging.wsi.tile,
    ds.imaging.embeddings.extract
  )
  expect_true(all(vapply(wrappers, function(fun) {
    identical(formals(fun)$handle, "img")
  }, logical(1))))
  expect_false("allow_partial" %in%
    names(formals(ds.imaging.radiomics.process_collection)))
  expect_false("allow_partial" %in%
    names(formals(ds.imaging.radiomics.collection_publish)))
})

test_that("global dataset registry listing directs users to resource handles", {
  expect_error(ds.imaging.datasets(NULL), "ds.imaging.init", fixed = TRUE)
})

test_that("clinical imaging workflow requests declare expected runners", {
  expect_no_error(dsImagingClient:::.imaging_asset_job("ds1", "qc_metrics",
    runner = "imaging_qc_metrics", config = list(image_asset = "images"),
    output_asset = "imaging_qc", asset_type = "qc_table",
    visibility = "global"))

  req <- dsImagingClient:::.imaging_asset_job("ds1", "qc_metrics",
    runner = "imaging_qc_metrics",
    config = list(dataset_id = "ds1", image_asset = "images"),
    output_asset = "imaging_qc",
    asset_type = "qc_table",
    alias = "latest_qc")

  expect_equal(req$domain_method, "imagingProcessAssetWorkflowDS")
  expect_equal(req$handle, "img")
  expect_equal(req$runner, "imaging_qc_metrics")
  expect_null(req$asset_type)
  expect_null(req$label_tag)
  expect_equal(req$alias, "latest_qc")
  expect_null(req$visibility)
  expect_equal(req$config$image_asset, "images")
  expect_null(req$config$dataset_id)

  runners <- c("rt_convert", "rt_dose_plan", "imaging_qc_visuals",
               "image_spatial", "wsi_tile", "image_embeddings")
  asset_types <- c("mask_root", "dose_table", "qc_visual_asset",
                   "image_root", "wsi_tile_root", "embedding_table")
  for (i in seq_along(runners)) {
    derived <- dsImagingClient:::.imaging_asset_job("ds1", runners[[i]],
      runner = runners[[i]],
      config = list(dataset_id = "ds1"),
      output_asset = paste0("asset_", i),
      asset_type = asset_types[[i]])
    expect_equal(derived$runner, runners[[i]])
    expect_null(derived$asset_type)
    expect_null(derived$label_tag)
    expect_null(derived$config$dataset_id)
  }
})

test_that("asset loading wrappers expose metadata join option", {
  expect_true("include_metadata" %in% names(formals(ds.imaging.load_asset)))
  expect_true("include_metadata" %in% names(formals(ds.imaging.radiomics.load_features)))
  expect_true("syntactic_names" %in% names(formals(ds.imaging.load_asset)))
  expect_true("syntactic_names" %in% names(formals(ds.imaging.radiomics.load_features)))
})

test_that("advanced imaging workflow functions are exported", {
  exports <- getNamespaceExports("dsImagingClient")
  expect_true("ds.imaging.rt.convert" %in% exports)
  expect_true("ds.imaging.rt.dose" %in% exports)
  expect_true("ds.imaging.qc.visuals" %in% exports)
  expect_true("ds.imaging.spatial.process" %in% exports)
  expect_true("ds.imaging.wsi.tile" %in% exports)
  expect_true("ds.imaging.embeddings.extract" %in% exports)
})
