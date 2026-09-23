test_that("model discovery preserves verified manifest identity and readiness", {
  bundles <- data.frame(
    provider = c("lungmask", "monai"), task = c("R231", "approved_bundle"),
    ready = c(TRUE, FALSE), manifest_sha256 = c(strrep("a", 64L), strrep("b", 64L)),
    stringsAsFactors = FALSE)
  calls <- list()
  local_mocked_bindings(
    .ds_safe_aggregate = function(conns, expr) {
      calls[[length(calls) + 1L]] <<- expr
      if (identical(expr[[1L]], as.name("imagingCapabilitiesDS"))) {
        return(list(site = list(models = bundles)))
      }
      list(site = bundles)
    },
    .package = "dsImagingClient")

  expect_identical(ds.imaging.models(list(site = list()))$site, bundles)
  expect_identical(ds.imaging.capabilities(list(site = list()))$site$models,
    bundles)
  expect_identical(calls, list(call("imagingListModelsDS"),
    call("imagingCapabilitiesDS")))
})

test_that("administrator installation reports its verified manifest digest", {
  observed <- NULL
  installed <- list(site = list(status = "installed", provider = "lungmask",
    task = "R231", manifest_sha256 = strrep("c", 64L)))
  local_mocked_bindings(
    .ds_safe_aggregate = function(conns, expr) {
      observed <<- expr
      installed
    },
    .package = "dsImagingClient")

  output <- capture.output(result <- ds.imaging.install_model(
    list(site = list()), "test-admin-key", "lungmask", "R231"))
  expect_identical(result, installed)
  expect_match(paste(output, collapse = "\n"), strrep("c", 64L), fixed = TRUE)
  expect_identical(observed[[1L]], as.name("imagingInstallModelDS"))
  expect_identical(as.character(observed[[3L]]), "lungmask")
  expect_identical(as.character(observed[[4L]]), "R231")
  key <- chartr("-_", "+/", sub("^B64:", "", observed[[2L]]))
  key <- paste0(key, strrep("=", (4L - nchar(key) %% 4L) %% 4L))
  expect_identical(jsonlite::fromJSON(rawToChar(jsonlite::base64_dec(key))),
    list(.admin_key = "test-admin-key"))
  expect_false(grepl("test-admin-key", paste(output, collapse = "\n"), fixed = TRUE))
})

test_that("learned segmenter requests select names without model paths", {
  expect_named(ds.imaging.segmenter.lungmask("R231"), c("provider", "model_name"))
  expect_named(ds.imaging.segmenter.totalsegmentator(),
    c("provider", "task", "fast", "roi_subset"))
  expect_named(ds.imaging.segmenter.nnunet("approved_model"),
    c("provider", "model_name", "fold"))
  expect_named(ds.imaging.segmenter.monai_bundle("approved_bundle"),
    c("provider", "bundle_name"))
})
