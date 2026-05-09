#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(DSI)
  library(DSOpal)
  library(dsImagingClient)
  library(dsBaseClient)
})

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

env <- function(name, default = "") {
  value <- Sys.getenv(name, "")
  if (nzchar(value)) value else default
}

logical_env <- function(name, default = "FALSE") {
  value <- toupper(env(name, default))
  value %in% c("1", "TRUE", "YES", "Y")
}

workdir <- normalizePath(env("LUNG1_WORKDIR", "/tmp/dsimaging_lung1_study"),
                         mustWork = TRUE)
publish <- logical_env("LUNG1_PUBLISH", "TRUE")
only_publish <- logical_env("LUNG1_ONLY_PUBLISH", "FALSE")
run_jobs <- logical_env("LUNG1_RUN_JOBS", "TRUE")
async <- logical_env("LUNG1_ASYNC", "TRUE")
run_glm <- logical_env("LUNG1_RUN_GLM", "TRUE")
timeout <- as.numeric(env("LUNG1_TIMEOUT", "1800"))
poll_interval <- as.numeric(env("LUNG1_POLL_INTERVAL", "60"))
batch_size <- as.integer(env("LUNG1_BATCH_SIZE", "1"))
admin_python <- env("DSIMAGING_ADMIN_PYTHON", "/opt/homebrew/bin/python3.11")
if (!file.exists(admin_python)) admin_python <- Sys.which("python3")
dataset_prefix <- env("LUNG1_DATASET_PREFIX", "lung1_site")
dataset_suffixes <- c(a = "a", b = "b", c = "c")

sites <- data.frame(
  server = c("opal1", "opal2", "opal3"),
  site = c("site_a", "site_b", "site_c"),
  dataset = paste0(dataset_prefix, "_", dataset_suffixes),
  opal_url = c("https://localhost:8443", "https://localhost:8444",
               "https://localhost:8445"),
  stringsAsFactors = FALSE
)

publish_site <- function(row) {
  source_dir <- file.path(workdir, "sites", row$site)
  metadata <- file.path(source_dir, "metadata.csv")
  args <- c(
    "-m", "dsimaging_admin.cli",
    "--endpoint", env("DSIMAGING_ENDPOINT", "http://127.0.0.1:9000"),
    "--access-key", env("DSIMAGING_ACCESS_KEY", "minioadmin"),
    "--secret-key", env("DSIMAGING_SECRET_KEY", "minioadmin123"),
    "publish",
    "--dataset-id", row$dataset,
    "--source", source_dir,
    "--metadata", metadata,
    "--modality", "ct",
    "--resource-endpoint", env("DSIMAGING_RESOURCE_ENDPOINT", "http://minio.local:9000"),
    "--opal-url", row$opal_url,
    "--opal-user", env("OPAL_USER", "administrator"),
    "--opal-password", env("OPAL_PASSWORD", "admin123"),
    "--opal-project", env("LUNG1_OPAL_PROJECT", "dsdemo"),
    "--opal-resource", env("LUNG1_OPAL_RESOURCE", "lung1_study"),
    "--opal-replace",
    "--opal-insecure"
  )
  message("Publishing ", row$dataset, " from ", source_dir)
  status <- system2(admin_python, args)
  if (!identical(status, 0L)) {
    stop("Publishing failed for ", row$dataset, call. = FALSE)
  }
}

if (publish) {
  for (i in seq_len(nrow(sites))) publish_site(sites[i, ])
}

if (only_publish) {
  message("Publish-only mode completed.")
  quit(save = "no", status = 0)
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

conns <- datashield.login(logins = logins, assign = FALSE)
on.exit(datashield.logout(conns), add = TRUE)

resource <- paste0(env("LUNG1_OPAL_PROJECT", "dsdemo"), ".",
                   env("LUNG1_OPAL_RESOURCE", "lung1_study"))
ds.imaging.init(conns, resource, symbol = "img")
print(ds.imaging.metadata(conns, "img"))
print(ds.imaging.validate(conns, "img"))

is_collection_asset_ready <- function(x) {
  !is.null(x$asset_id) && length(x$asset_id) == 1L && nzchar(x$asset_id)
}

wait_and_publish_collections <- function(conns, result, result_path,
                                         poll_interval = 60,
                                         timeout = 0) {
  started <- Sys.time()
  repeat {
    for (srv in names(result)) {
      item <- result[[srv]]
      if (is_collection_asset_ready(item)) next
      status <- ds.imaging.radiomics.collection_status(
        conns[srv], item$generation_id)
      message(
        srv, ": ", status$completed %||% 0L, "/", status$total %||% item$total,
        " completed; failed=", status$failed %||% 0L,
        "; pending=", status$pending %||% NA_integer_
      )
      if (isTRUE(status$is_done)) {
        result[[srv]] <- ds.imaging.radiomics.collection_publish(
          conns[srv], item$generation_id, item$dataset_id,
          allow_partial = FALSE)
        saveRDS(result, result_path)
      }
    }
    if (all(vapply(result, is_collection_asset_ready, logical(1)))) {
      return(result)
    }
    if (timeout > 0 &&
        as.numeric(difftime(Sys.time(), started, units = "secs")) > timeout) {
      warning("Timed out while waiting for async radiomics collections. ",
              "Server jobs continue; rerun with LUNG1_RUN_JOBS=FALSE once done.",
              call. = FALSE)
      saveRDS(result, result_path)
      return(result)
    }
    Sys.sleep(poll_interval)
  }
}

result_path <- file.path(workdir, "datashield_radiomics_result.rds")
if (run_jobs) {
  result <- list()
  for (srv in names(conns)) {
    message("Starting radiomics on ", srv)
    result[[srv]] <- ds.imaging.radiomics.process_collection(
      conns[srv],
      dataset_id = NULL,
      segmenter = ds.imaging.segmenter.existing_mask("masks"),
      profile = ds.imaging.radiomics.profile.aerts_signature(),
      batch_size = batch_size,
      poll_interval = poll_interval,
      timeout = if (async) 0 else timeout,
      allow_partial = FALSE,
      visibility = "global"
    )
    saveRDS(result, result_path)
  }
  if (async) {
    if (identical(timeout, 0)) {
      message("Fire-and-forget mode: jobs have been kicked off.")
      message("Rerun with LUNG1_PUBLISH=FALSE LUNG1_RUN_JOBS=FALSE ",
              "to wait, publish, and analyse completed collections.")
      quit(save = "no", status = 0)
    } else {
      result <- wait_and_publish_collections(conns, result, result_path,
                                             poll_interval = poll_interval,
                                             timeout = timeout)
    }
  }
  saveRDS(result, result_path)
} else if (file.exists(result_path)) {
  result <- readRDS(result_path)
  if (any(!vapply(result, is_collection_asset_ready, logical(1)))) {
    result <- wait_and_publish_collections(conns, result, result_path,
                                           poll_interval = poll_interval,
                                           timeout = timeout)
  }
} else {
  stop("LUNG1_RUN_JOBS=FALSE but no previous result exists at ",
       result_path, call. = FALSE)
}

for (srv in names(result)) {
  ds.imaging.radiomics.load_features(
    conns[srv],
    dataset_id = result[[srv]]$dataset_id,
    asset_id = result[[srv]]$asset_id,
    symbol = "rad",
    include_metadata = TRUE,
    syntactic_names = TRUE
  )
}

features <- c(
  "original_firstorder_Energy",
  "original_shape_Compactness1",
  "original_glrlm_RunLengthNonUniformity",
  "wavelet.HLH_glrlm_RunLengthNonUniformity"
)

federated <- do.call(rbind, lapply(features, function(feature) {
  mean_by_study <- ds.mean(paste0("rad$", feature), datasources = conns)$Mean.by.Study
  data.frame(
    server = rownames(mean_by_study),
    feature = feature,
    federated = as.numeric(mean_by_study[, "EstimatedMean"]),
    row.names = NULL
  )
}))

print(ds.dim("rad", datasources = conns))
print(ds.mean("rad$survival_time_days", datasources = conns))
print(ds.mean("rad$os_2yr_alive", datasources = conns))

central_path <- file.path(workdir, "central", "aerts_features.csv")
comparison <- NULL
if (file.exists(central_path)) {
  central <- read.csv(central_path, check.names = TRUE)
  central$server <- c(site_a = "opal1", site_b = "opal2",
                      site_c = "opal3")[central$site]
  central_long <- do.call(rbind, lapply(features, function(feature) {
    mean_by_site <- aggregate(central[[feature]],
                              by = list(server = central$server), mean)
    data.frame(server = mean_by_site$server, feature = feature,
               central = mean_by_site$x, row.names = NULL)
  }))
  comparison <- merge(federated, central_long, by = c("server", "feature"))
  comparison$abs_diff <- abs(comparison$federated - comparison$central)
  print(comparison)
  write.csv(comparison, file.path(workdir, "federated_vs_central_means.csv"),
            row.names = FALSE)
} else {
  message("No central baseline found at ", central_path,
          "; writing federated summaries only.")
  write.csv(federated, file.path(workdir, "federated_feature_means.csv"),
            row.names = FALSE)
}

glm_fit <- NULL
if (run_glm) {
  glm_formula <- stats::as.formula(paste(
    "os_2yr_alive ~",
    paste(c(features, "age", "gender_male"), collapse = " + ")
  ))
  glm_fit <- tryCatch(
    ds.glmSLMA(
      formula = glm_formula,
      family = "binomial",
      dataName = "rad",
      datasources = conns
    ),
    error = function(e) e
  )
  print(glm_fit)
}

saveRDS(list(result = result, federated = federated, comparison = comparison,
             glm = glm_fit),
        file.path(workdir, "federated_study_summary.rds"))
