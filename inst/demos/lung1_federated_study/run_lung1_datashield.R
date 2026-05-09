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

workdir <- normalizePath(env("LUNG1_WORKDIR", "/tmp/dsimaging_lung1_study"),
                         mustWork = TRUE)
publish <- as.logical(env("LUNG1_PUBLISH", "TRUE"))
run_jobs <- as.logical(env("LUNG1_RUN_JOBS", "TRUE"))
timeout <- as.numeric(env("LUNG1_TIMEOUT", "1800"))
admin_python <- env("DSIMAGING_ADMIN_PYTHON", "/opt/homebrew/bin/python3.11")
if (!file.exists(admin_python)) admin_python <- Sys.which("python3")

sites <- data.frame(
  server = c("opal1", "opal2", "opal3"),
  site = c("site_a", "site_b", "site_c"),
  dataset = c("lung1_site_a", "lung1_site_b", "lung1_site_c"),
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

result_path <- file.path(workdir, "datashield_radiomics_result.rds")
if (run_jobs || !file.exists(result_path)) {
  result <- ds.imaging.radiomics.process_collection(
    conns,
    dataset_id = NULL,
    segmenter = ds.imaging.segmenter.existing_mask("masks"),
    profile = ds.imaging.radiomics.profile.aerts_signature(),
    batch_size = 1L,
    poll_interval = 10,
    timeout = timeout,
    allow_partial = FALSE,
    visibility = "global"
  )
  saveRDS(result, result_path)
} else {
  result <- readRDS(result_path)
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

central <- read.csv(file.path(workdir, "central", "aerts_features.csv"),
                    check.names = TRUE)
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
print(ds.dim("rad", datasources = conns))
print(comparison)
print(ds.mean("rad$survival_time_days", datasources = conns))
print(ds.mean("rad$os_2yr_alive", datasources = conns))

write.csv(comparison, file.path(workdir, "federated_vs_central_means.csv"),
          row.names = FALSE)
saveRDS(list(result = result, comparison = comparison),
        file.path(workdir, "federated_vs_central_summary.rds"))
