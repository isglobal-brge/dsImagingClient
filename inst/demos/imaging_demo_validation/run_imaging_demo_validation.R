#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(DSI)
  library(DSOpal)
  library(dsBaseClient)
  library(dsHPCClient)
  library(dsImagingClient)
  library(jsonlite)
  library(opalr)
})

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

env <- function(name, default = "") {
  value <- Sys.getenv(name, "")
  if (nzchar(value)) value else default
}

logical_env <- function(name, default = "FALSE") {
  toupper(env(name, default)) %in% c("1", "TRUE", "YES", "Y")
}

url_encode <- function(x) utils::URLencode(x, reserved = TRUE)

workdir <- normalizePath(env("IMAGING_DEMO_WORKDIR",
                             "/tmp/dsimaging_imaging_demo"),
                         mustWork = TRUE)
publish <- logical_env("IMAGING_DEMO_PUBLISH", "TRUE")
replace <- logical_env("IMAGING_DEMO_REPLACE", "FALSE")
run_jobs <- logical_env("IMAGING_DEMO_RUN_JOBS", "TRUE")
timeout <- as.numeric(env("IMAGING_DEMO_TIMEOUT", "1200"))
poll_interval <- as.numeric(env("IMAGING_DEMO_POLL_INTERVAL", "5"))
opal_project <- env("IMAGING_DEMO_OPAL_PROJECT", "dsdemo")
opal_resource <- env("IMAGING_DEMO_OPAL_RESOURCE", "imaging_demo")

sites <- data.frame(
  server = c("opal1", "opal2", "opal3"),
  site = c("site_a", "site_b", "site_c"),
  dataset = c("imaging_demo_a", "imaging_demo_b", "imaging_demo_c"),
  opal_url = c("https://localhost:8443", "https://localhost:8444",
               "https://localhost:8445"),
  stringsAsFactors = FALSE
)

admin_cmd <- env("DSIMAGING_ADMIN", Sys.which("dsimaging-admin"))
admin_python <- env("DSIMAGING_ADMIN_PYTHON", Sys.which("python3"))

run_admin <- function(args) {
  base_args <- c(
    "--endpoint", env("DSIMAGING_ENDPOINT", "http://127.0.0.1:9000"),
    "--access-key", env("DSIMAGING_ACCESS_KEY", "minioadmin"),
    "--secret-key", env("DSIMAGING_SECRET_KEY", "minioadmin123"),
    "--bucket", env("DSIMAGING_BUCKET", "imaging-data")
  )
  if (nzchar(admin_cmd)) {
    status <- system2(admin_cmd, c(base_args, args))
  } else if (nzchar(admin_python)) {
    status <- system2(admin_python,
                      c("-m", "dsimaging_admin.cli", base_args, args))
  } else {
    stop("Cannot find dsimaging-admin or python3.", call. = FALSE)
  }
  if (!identical(status, 0L)) {
    stop("dsimaging-admin failed with exit status ", status, call. = FALSE)
  }
  invisible(TRUE)
}

publish_site <- function(row) {
  source_dir <- file.path(workdir, "sites", row$site)
  metadata <- file.path(source_dir, "metadata.csv")
  if (!dir.exists(source_dir) || !file.exists(metadata)) {
    stop("Missing prepared site directory: ", source_dir,
         ". Run prepare_imaging_demo.py first.", call. = FALSE)
  }

  if (replace) {
    try(run_admin(c("dataset", "delete", row$dataset, "--yes",
                    "--purge-versions")), silent = TRUE)
  }
  run_admin(c(
    "dataset", "publish",
    "--dataset-id", row$dataset,
    "--source", source_dir,
    "--metadata", metadata,
    "--modality", "ct",
    "--no-atomic",
    "--skip-dicom-checks"
  ))
}

register_resource <- function(row) {
  opal <- opal.login(env("OPAL_USER", "administrator"),
                     env("OPAL_PASSWORD", "admin123"),
                     url = row$opal_url,
                     opts = list(ssl_verifyhost = 0L, ssl_verifypeer = 0L))
  on.exit(opal.logout(opal), add = TRUE)
  if (opal.resource_exists(opal, opal_project, opal_resource)) {
    opal.resource_delete(opal, opal_project, opal_resource, silent = TRUE)
  }
  resource_url <- sprintf(
    "imaging+dataset://%s?endpoint=%s&bucket=%s&prefix=%s",
    row$dataset,
    url_encode(env("DSIMAGING_RESOURCE_ENDPOINT",
                   "http://dsimaging-store-minio-1:9000")),
    env("DSIMAGING_BUCKET", "imaging-data"),
    url_encode(file.path("datasets", row$dataset))
  )
  opal.resource_create(
    opal, project = opal_project, name = opal_resource, url = resource_url,
    description = "dsImaging validation demo resource",
    identity = env("DSIMAGING_ACCESS_KEY", "minioadmin"),
    secret = env("DSIMAGING_SECRET_KEY", "minioadmin123")
  )
}

submit_by_site <- function(conns, dataset_ids, fun) {
  out <- list()
  for (srv in names(conns)) {
    out[[srv]] <- fun(conns[srv], dataset_ids[[srv]])
  }
  out
}

wait_by_site <- function(conns, label, submissions, timeout, poll_interval) {
  message("\n== ", label, " ==")
  status <- list()
  for (srv in names(submissions)) {
    message("-- ", srv, " ", submissions[[srv]]$symbol)
    status[[srv]] <- ds.hpc.wait(
      conns[srv], submissions[[srv]]$symbol,
      timeout = timeout, poll_interval = poll_interval
    )
    print(status[[srv]])
  }
  status
}

load_dims <- function(conns, dataset_ids, alias_or_assets, symbol,
                      loader = c("asset", "radiomics"),
                      include_metadata = TRUE) {
  loader <- match.arg(loader)
  dims <- list()
  for (srv in names(conns)) {
    if (identical(loader, "asset")) {
      ds.imaging.load_asset(
        conns[srv], dataset_ids[[srv]], alias_or_assets, symbol = symbol,
        include_metadata = include_metadata, syntactic_names = TRUE
      )
    } else {
      ds.imaging.radiomics.load_features(
        conns[srv], dataset_ids[[srv]], alias_or_assets[[srv]],
        symbol = symbol, include_metadata = include_metadata,
        syntactic_names = TRUE
      )
    }
    dims[[srv]] <- as.integer(ds.dim(symbol, datasources = conns[srv])[[1]])
  }
  dims
}

asset_details <- function(conns, dataset_ids, alias) {
  details <- list()
  for (srv in names(conns)) {
    details[[srv]] <- ds.imaging.asset(conns[srv], alias,
                                       dataset_ids[[srv]])[[srv]]
  }
  details
}

asset_details_by_site <- function(conns, dataset_ids) {
  out <- list()
  for (srv in names(conns)) {
    out[[srv]] <- list(
      mask_connected_components = ds.imaging.asset(
        conns[srv], "demo_masks_cc", dataset_ids[[srv]]
      )[[srv]],
      crop_to_mask = ds.imaging.asset(
        conns[srv], "demo_crop_to_mask", dataset_ids[[srv]]
      )[[srv]],
      qc_metrics = ds.imaging.asset(
        conns[srv], "demo_qc_metrics", dataset_ids[[srv]]
      )[[srv]],
      embeddings = ds.imaging.asset(
        conns[srv], "demo_embeddings", dataset_ids[[srv]]
      )[[srv]]
    )
  }
  out
}

if (publish) {
  for (i in seq_len(nrow(sites))) {
    publish_site(sites[i, ])
    register_resource(sites[i, ])
  }
}

logins <- data.frame(
  server = sites$server,
  url = sites$opal_url,
  user = env("OPAL_USER", "administrator"),
  password = env("OPAL_PASSWORD", "admin123"),
  driver = "OpalDriver",
  options = "list(ssl_verifyhost=0L, ssl_verifypeer=0L)",
  profile = "default",
  stringsAsFactors = FALSE
)

conns <- datashield.login(logins, assign = FALSE)
on.exit(datashield.logout(conns), add = TRUE)
dataset_ids <- stats::setNames(sites$dataset, sites$server)

resource <- paste0(opal_project, ".", opal_resource)
ds.imaging.init(conns, resource, symbol = "img")
metadata <- ds.imaging.metadata(conns, "img")
validation <- ds.imaging.validate(conns, "img")
print(vapply(metadata, function(x) x$n_samples, integer(1)))
print(validation)

if (!run_jobs) {
  message("IMAGING_DEMO_RUN_JOBS=FALSE; stopping after publish/init/validate.")
  quit(save = "no", status = 0)
}

qc_jobs <- submit_by_site(conns, dataset_ids, function(cx, dsid) {
  ds.imaging.qc.metrics(
    cx, dataset_id = dsid, image_asset = "images", mask_asset = "masks",
    output_asset = "demo_qc_metrics",
    alias = "demo_qc_metrics"
  )
})
qc_status <- wait_by_site(conns, "QC metrics with masks", qc_jobs,
                          timeout, poll_interval)

mask_jobs <- submit_by_site(conns, dataset_ids, function(cx, dsid) {
  ds.imaging.mask.operation(
    cx, dataset_id = dsid, operation = "connected_components",
    mask_asset = "masks", reference_asset = "images",
    min_voxels = 5L, max_components = 1L,
    output_asset = "demo_masks_cc",
    alias = "demo_masks_cc"
  )
})
mask_status <- wait_by_site(conns, "Mask connected components", mask_jobs,
                            timeout, poll_interval)

spatial_jobs <- submit_by_site(conns, dataset_ids, function(cx, dsid) {
  ds.imaging.spatial.process(
    cx, dataset_id = dsid, image_asset = "images",
    operations = "crop_to_mask", mask_asset = "masks",
    output_asset = "demo_crop_to_mask",
    alias = "demo_crop_to_mask"
  )
})
spatial_status <- wait_by_site(conns, "Spatial crop to mask", spatial_jobs,
                               timeout, poll_interval)

embedding_jobs <- submit_by_site(conns, dataset_ids, function(cx, dsid) {
  ds.imaging.embeddings.extract(
    cx, dataset_id = dsid, image_asset = "images",
    model = "intensity_histogram", bins = 16L,
    output_asset = "demo_embeddings",
    alias = "demo_embeddings"
  )
})
embedding_status <- wait_by_site(conns, "Image embeddings", embedding_jobs,
                                 timeout, poll_interval)

message("\n== Existing-mask radiomics collections ==")
existing_rad <- list()
for (srv in names(conns)) {
  message("-- ", srv)
  existing_rad[[srv]] <- ds.imaging.radiomics.process_collection(
    conns[srv], dataset_id = NULL,
    segmenter = ds.imaging.segmenter.existing_mask("masks"),
    profile = ds.imaging.radiomics.profile.demo_ct_firstorder(),
    batch_size = 2L, poll_interval = poll_interval, timeout = timeout
  )
  print(existing_rad[[srv]])
}

message("\n== Threshold segmentation -> radiomics collections ==")
segmented_rad <- list()
for (srv in names(conns)) {
  message("-- ", srv)
  segmented_rad[[srv]] <- ds.imaging.radiomics.segment_and_extract(
    conns[srv], dataset_id = NULL,
    segmenter = ds.imaging.segmenter.ct_lung_threshold(
      threshold = -320, max_components = 2L, min_voxels = 100L
    ),
    profile = ds.imaging.radiomics.profile.demo_ct_firstorder(),
    batch_size = 2L, poll_interval = poll_interval, timeout = timeout
  )
  print(segmented_rad[[srv]])
}

existing_assets <- vapply(existing_rad, `[[`, character(1), "asset_id")
segmented_assets <- vapply(segmented_rad, `[[`, character(1), "asset_id")

qc_dims <- load_dims(conns, dataset_ids, "demo_qc_metrics", "qc_demo")
embedding_dims <- load_dims(conns, dataset_ids, "demo_embeddings", "emb_demo")
existing_dims <- load_dims(conns, dataset_ids, existing_assets, "rad_existing",
                           "radiomics")
segmented_dims <- load_dims(conns, dataset_ids, segmented_assets,
                            "rad_segmented", "radiomics")

mean_by_site <- function(expr) {
  result <- ds.mean(expr, datasources = conns)$Mean.by.Study
  as.list(stats::setNames(as.numeric(result[, "EstimatedMean"]),
                          rownames(result)))
}

job_status_summary <- function(status, expected = 10L) {
  lapply(names(status), function(srv) {
    item <- status[[srv]]
    state <- item$state %||% NA_character_
    list(
      state = state,
      pass = identical(state, "FINISHED"),
      expected = expected
    )
  }) |> stats::setNames(names(status))
}

dimension_status <- function(dims, expected_rows = 10L, expected_min_cols = 1L) {
  lapply(names(dims), function(srv) {
    item <- as.integer(dims[[srv]])
    rows <- item[[1]]
    cols <- item[[2]]
    list(
      rows = rows,
      columns = cols,
      pass = identical(rows, as.integer(expected_rows)) &&
        cols >= as.integer(expected_min_cols)
    )
  }) |> stats::setNames(names(dims))
}

generic_asset_status <- function(details, key, expected = 10L) {
  lapply(names(details), function(srv) {
    item <- details[[srv]][[key]]
    summaries <- item$provenance$output$summaries
    summary <- summaries[[names(summaries)[1]]]
    completed <- summary$n_done %||% summary$n_images %||% summary$n_samples
    failed <- summary$n_failed %||% 0L
    list(
      asset_id = item$asset_id,
      kind = item$kind,
      completed = as.integer(completed),
      failed = as.integer(failed),
      pass = identical(as.integer(completed), as.integer(expected)) &&
        identical(as.integer(failed), 0L)
    )
  }) |> stats::setNames(names(details))
}

all_pass <- function(x) {
  if (is.list(x) && !is.null(x$pass)) return(isTRUE(x$pass))
  if (is.list(x)) return(all(vapply(x, all_pass, logical(1))))
  isTRUE(x)
}

generic_assets <- asset_details_by_site(conns, dataset_ids)

summary <- list(
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  resource = resource,
  datasets = as.list(dataset_ids),
  samples_per_site = as.list(vapply(metadata, function(x) x$n_samples,
                                    integer(1))),
  validation = as.list(vapply(validation, isTRUE, logical(1))),
  dimensions = list(
    qc_metrics = qc_dims,
    embeddings = embedding_dims,
    existing_mask_radiomics = existing_dims,
    segmented_radiomics = segmented_dims
  ),
  qc_aggregates = list(
    mask_volume_mean = mean_by_site("qc_demo$mask_volume"),
    mask_voxels_mean = mean_by_site("qc_demo$mask_voxels"),
    masked_mean_hu = mean_by_site("qc_demo$masked_mean"),
    n_valid = as.list(vapply(metadata, function(x) x$n_samples, integer(1)))
  ),
  assets = list(
    existing_mask_radiomics = as.list(existing_assets),
    segmented_radiomics = as.list(segmented_assets)
  ),
  workflow_status = list(
    qc_metrics = dimension_status(qc_dims, expected_rows = 10L,
                                  expected_min_cols = 20L),
    mask_connected_components = generic_asset_status(
      generic_assets, "mask_connected_components", expected = 10L),
    crop_to_mask = generic_asset_status(
      generic_assets, "crop_to_mask", expected = 10L),
    embeddings = dimension_status(embedding_dims, expected_rows = 10L,
                                  expected_min_cols = 24L),
    existing_mask_radiomics = dimension_status(
      existing_dims, expected_rows = 10L, expected_min_cols = 20L),
    segmented_radiomics = dimension_status(
      segmented_dims, expected_rows = 10L, expected_min_cols = 20L)
  )
)
summary$overall_pass <- all(vapply(summary$validation, isTRUE, logical(1))) &&
  all_pass(summary$workflow_status)
summary$generic_assets <- generic_assets

result_dir <- file.path(workdir, "results")
dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)
out <- file.path(result_dir, "imaging_demo_validation_summary.json")
write_json(summary, out, auto_unbox = TRUE, pretty = TRUE)
message("Wrote ", out)
