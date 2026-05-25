test_that("store, client injection, and dsHPC hashing work together", {
  testthat::skip_if_not_installed("dsImaging")
  testthat::skip_if_not_installed("dsHPC")
  testthat::skip_if_not(
    exists(".content_hash_handle_minio_event",
      envir = asNamespace("dsImaging"), inherits = FALSE),
    "requires current dsImaging content-hash provider")
  testthat::skip_if_not(
    exists(".canonicalise_spec", envir = asNamespace("dsHPC"),
      inherits = FALSE),
    "requires current dsHPC canonical hashing")

  db_path <- tempfile(fileext = ".sqlite")
  withr::local_options(list(
    dsimaging.asset_db = db_path,
    dsimagingstore.resource_mapper = function(bucket, object_key) "lung1",
    dsimagingclient.content_hash_resolver = function(conns, resource_name) {
      result <- dsImaging::contentHashDS(resource_name)
      stats::setNames(result$content_hash, "server_1")
    }
  ))

  payload <- function(etag) {
    jsonlite::toJSON(list(Records = list(list(
      s3 = list(bucket = list(name = "imaging-objects"),
        object = list(key = "lung1/object.nii.gz", eTag = etag))
    ))), auto_unbox = TRUE)
  }
  dsImaging:::.content_hash_handle_minio_event(payload(
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))

  job <- dsHPCClient::ds_job(
    label = "dsImaging",
    steps = list(dsHPCClient::ds_step_resolve_dataset("lung1"))
  )
  job_hash <- function(x) {
    spec <- x[setdiff(names(x), c("job_id", ".owner", "name"))]
    digest::digest(jsonlite::toJSON(dsHPC:::.canonicalise_spec(spec),
      auto_unbox = TRUE), algo = "sha256", serialize = FALSE)
  }

  first <- dsImagingClient:::.enrich_imaging_job_resources(
    list(server_1 = list()), job)
  second <- dsImagingClient:::.enrich_imaging_job_resources(
    list(server_1 = list()), job)
  expect_equal(job_hash(first), job_hash(second))

  dsImaging:::.content_hash_handle_minio_event(payload(
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"))
  third <- dsImagingClient:::.enrich_imaging_job_resources(
    list(server_1 = list()), job)
  expect_false(identical(job_hash(first), job_hash(third)))
})
