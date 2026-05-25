test_that("content hash injection enriches specs when the store is available", {
  withr::local_options(list(
    dsimagingclient.content_hash_resolver = function(conns, resource_name) {
      if (identical(resource_name, "lung1")) {
        return(c(server_1 = "sha256:lung1"))
      }
      c(server_1 = NA_character_)
    }
  ))

  job <- dsHPCClient::ds_job(
    label = "dsImaging",
    steps = list(
      dsHPCClient::ds_step_resolve_dataset("lung1"),
      dsHPCClient::ds_step_stage_tabular("lung1")
    )
  )

  enriched <- dsImagingClient:::.enrich_imaging_job_resources(
    list(server_1 = list()), job)
  expect_equal(enriched$content_hashes$lung1$content_hash, "sha256:lung1")
  expect_equal(enriched$steps[[2]]$resource$name, "lung1")
  expect_equal(enriched$steps[[2]]$resource$content_hash, "sha256:lung1")
  expect_equal(enriched$steps[[1]]$dataset_id, "lung1")
})

test_that("content hash injection falls back to bare specs when unavailable", {
  withr::local_options(list(
    dsimagingclient.content_hash_resolver = function(conns, resource_name) {
      c(server_1 = NA_character_)
    }
  ))

  job <- dsHPCClient::ds_job(
    label = "dsImaging",
    steps = list(dsHPCClient::ds_step_resolve_dataset("lung1"))
  )

  enriched <- dsImagingClient:::.enrich_imaging_job_resources(
    list(server_1 = list()), job)
  expect_null(enriched$content_hashes)
  expect_equal(enriched$steps[[1]]$dataset_id, "lung1")
})

test_that("unchanged resources inject stable hashes across submits", {
  withr::local_options(list(
    dsimagingclient.content_hash_resolver = function(conns, resource_name) {
      c(server_1 = paste0("sha256:", resource_name))
    }
  ))

  job <- dsHPCClient::ds_job(
    label = "dsImaging",
    steps = list(dsHPCClient::ds_step_resolve_dataset("lung1"))
  )

  first <- dsImagingClient:::.enrich_imaging_job_resources(
    list(server_1 = list()), job)
  second <- dsImagingClient:::.enrich_imaging_job_resources(
    list(server_1 = list()), job)

  expect_equal(first$content_hashes, second$content_hashes)
})
