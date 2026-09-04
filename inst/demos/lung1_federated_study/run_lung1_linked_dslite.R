#!/usr/bin/env Rscript

# Local one-node acceptance path for the clinical-table -> dsImaging ->
# radiomics -> opaque feature view -> dsFlower contract. The three-node
# Opal/Armadillo deployment uses the same client calls after administrators
# register each site's Resource and clinical table.

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

env <- function(name, default = "") {
  value <- Sys.getenv(name, "")
  if (nzchar(value)) value else default
}

main <- function() {
  workdir <- normalizePath(
    env("LUNG1_WORKDIR", "/tmp/dsimaging_lung1_study"), mustWork = TRUE)
  site <- env("LUNG1_DSLITE_SITE", "site_a")
  if (!site %in% c("site_a", "site_b", "site_c")) {
    stop("LUNG1_DSLITE_SITE must be site_a, site_b, or site_c.",
         call. = FALSE)
  }
  site_dir <- file.path(workdir, "sites", site)
  clinical_path <- file.path(site_dir, "clinical.csv")
  imaging_metadata_path <- file.path(site_dir, "metadata.csv")
  if (!file.exists(clinical_path) || !file.exists(imaging_metadata_path)) {
    stop("Missing prepared clinical/imaging metadata; rerun ",
         "prepare_lung1_study.py.", call. = FALSE)
  }

  endpoint <- env("DSIMAGING_ENDPOINT", "http://127.0.0.1:9000")
  bucket <- env("DSIMAGING_BUCKET", "imaging-data")
  dataset <- env(
    "LUNG1_DATASET_ID", paste0("lung1_linked_site_", sub("site_", "", site)))
  access_key <- env("DSIMAGING_ACCESS_KEY", env("MINIO_ROOT_USER"))
  secret_key <- env("DSIMAGING_SECRET_KEY", env("MINIO_ROOT_PASSWORD"))
  if (!nzchar(access_key) || !nzchar(secret_key)) {
    stop("Supply store credentials through the environment.", call. = FALSE)
  }

  state_dir <- env(
    "LUNG1_DSLITE_STATE",
    file.path(tempdir(), paste0("lung1-linked-", Sys.getpid())))
  dir.create(state_dir, recursive = TRUE, showWarnings = FALSE, mode = "0700")
  if (!dir.exists(state_dir)) stop("Could not create local state directory.")
  Sys.chmod(state_dir, "0700", use_umask = FALSE)

  analysis_venvs <- env(
    "DSIMAGING_ANALYSIS_VENV_ROOT", "/var/lib/dsimaging/venvs")
  worker_credentials_ref <- "lung1-local-store"
  imaging_data_dir <- file.path(state_dir, "dsimaging")
  asset_db <- file.path(imaging_data_dir, "assets.sqlite")
  credentials_path <- file.path(imaging_data_dir, "credentials.yaml")
  registry_path <- file.path(imaging_data_dir, "registry.yaml")
  options(
    dshpc.home = file.path(state_dir, "dshpc"),
    dshpc.worker_autostart = TRUE,
    dsimaging.data_dir = imaging_data_dir,
    dsimaging.asset_db = asset_db,
    dsimaging.credentials_path = credentials_path,
    dsimaging.registry_path = registry_path,
    dsimaging.worker_credentials_ref = worker_credentials_ref,
    dsimaging.analysis.venv_root = analysis_venvs,
    dsimaging.nfilter.subset = 10L,
    dsimaging.nfilter.tab = 10L,
    nfilter.subset = 10L,
    nfilter.tab = 10L,
    dsflower.min_train_rows = 10L,
    dsflower.dp_per_training_epsilon = 1,
    dsflower.dp_per_training_delta = 1e-6
  )
  Sys.setenv(
    DSIMAGING_DATA_DIR = imaging_data_dir,
    DSIMAGING_ASSET_DB = asset_db,
    DSIMAGING_CREDENTIALS_PATH = credentials_path,
    DSIMAGING_REGISTRY_PATH = registry_path,
    DSIMAGING_ANALYSIS_VENV_ROOT = analysis_venvs,
    DSIMAGING_WORKER_CREDENTIALS_REF = worker_credentials_ref,
    DSFLOWER_NODE_SECRET_FILE = file.path(state_dir, "flower-noise-root"),
    DSFLOWER_TEST_ALLOW_EPHEMERAL_SECRET = "1"
  )

  suppressPackageStartupMessages({
    library(DSI)
    library(DSLite)
    library(resourcer)
    library(dsHPC)
    library(dsImaging)
    library(dsFlower)
    library(dsImagingClient)
    library(dsFlowerClient)
    library(jsonlite)
  })
  on.exit(try(dsHPC:::.dshpc_worker_stop(), silent = TRUE), add = TRUE)
  # This script owns the disposable embedded DSLite node, so this is local
  # node-administrator bootstrap state. Production Opal/Armadillo nodes mount
  # a read-only, prefix-scoped credential reference themselves; analysts never
  # receive the secret.
  dsImaging:::.persist_s3_credential(worker_credentials_ref, list(
    access_key = access_key,
    secret_key = secret_key,
    endpoint = endpoint,
    region = ""
  ))

  resource_url <- paste0(
    "imaging+dataset://", dataset,
    "?endpoint=", utils::URLencode(endpoint, reserved = TRUE),
    "&bucket=", utils::URLencode(bucket, reserved = TRUE),
    "&prefix=", utils::URLencode(file.path("datasets", dataset),
                                  reserved = TRUE))
  resource <- resourcer::newResource(
    name = "images", url = resource_url,
    identity = access_key, secret = secret_key)
  clinical <- utils::read.csv(clinical_path, stringsAsFactors = FALSE,
                              check.names = FALSE)
  imaging_metadata <- utils::read.csv(
    imaging_metadata_path, stringsAsFactors = FALSE, check.names = FALSE)
  required_clinical <- c(
    "patient_id", "age", "gender_male", "os_2yr_alive")
  if (any(!required_clinical %in% names(clinical)) ||
      !identical(names(imaging_metadata), c("sample_id", "patient_id")) ||
      anyNA(imaging_metadata$sample_id) ||
      anyNA(imaging_metadata$patient_id) ||
      anyDuplicated(imaging_metadata$sample_id) ||
      anyNA(clinical$patient_id) ||
      anyDuplicated(clinical$patient_id) ||
      !setequal(imaging_metadata$patient_id, clinical$patient_id) ||
      anyNA(clinical[, required_clinical[-1L], drop = FALSE])) {
    stop("Prepared clinical and imaging rosters are inconsistent.",
         call. = FALSE)
  }

  config <- DSLite::defaultDSConfiguration(
    include = c("dsHPC", "dsImaging", "dsFlower"))
  server <- DSLite::newDSLiteServer(
    tables = list(clinical = clinical),
    resources = list(images = resource),
    config = config, home = file.path(state_dir, "dslite"))
  server_symbol <- paste0("lung1_linked_server_", Sys.getpid())
  assign(server_symbol, server, envir = .GlobalEnv)
  on.exit(rm(list = server_symbol, envir = .GlobalEnv), add = TRUE)
  conn <- DSLite::dsConnect(
    DSLite::DSLite(), name = site, url = server_symbol)
  on.exit(try(DSI::dsDisconnect(conn), silent = TRUE), add = TRUE)
  conns <- stats::setNames(list(conn), site)
  DSLite::dsAssignTable(conn, "clinical", "clinical")

  ds.imaging.init(conns, resource = "images", symbol = "img")
  on.exit(try(ds.imaging.destroy(conns, "img"), silent = TRUE), add = TRUE)
  radiomics <- ds.imaging.radiomics.process_collection(
    conns,
    segmenter = ds.imaging.segmenter.existing_mask("masks"),
    profile = ds.imaging.radiomics.profile.aerts_signature(),
    batch_size = 4L,
    poll_interval = 2,
    timeout = 1800,
    handle = "img"
  )
  if (!identical(radiomics$state, "ACTIVE") ||
      !is.character(radiomics$asset_id) || length(radiomics$asset_id) != 1L) {
    stop("Radiomics collection was not published.", call. = FALSE)
  }

  # Energy is extracted by the Aerts profile but is not used for this DP model:
  # its natural scale exceeds dsFlower's public clipping-bound domain. Keeping
  # the three scale-compatible signature features avoids collapsing Energy to
  # one clipping limit merely to make the example run.
  radiomics_features <- c(
    "original_shape_Compactness1",
    "original_glrlm_RunLengthNonUniformity",
    "wavelet-HLH_glrlm_RunLengthNonUniformity"
  )
  clinical_features <- c("age", "gender_male")
  model_features <- c(radiomics_features, clinical_features)
  ds.imaging.feature_view(
    conns,
    asset_id = radiomics$asset_id,
    symbol = "lung1_study",
    columns = radiomics_features,
    handle = "img",
    clinical_symbol = "clinical",
    clinical_id_col = "patient_id",
    clinical_columns = clinical_features,
    target_col = "os_2yr_alive",
    target_levels = c("0", "1")
  )
  on.exit(try(ds.imaging.feature_view.destroy(
    conns, "lung1_study"), silent = TRUE), add = TRUE)

  output_dir <- file.path(state_dir, "dsflower-output")
  fit <- ds.flower.fit(
    conns,
    symbol = "lung1_study",
    target = "os_2yr_alive",
    features = model_features,
    model = "pytorch_logreg",
    model_params = list(batch_size = 4L, local_epochs = 1L),
    torch_backend = "cpu",
    rounds = 1L,
    feature_bounds = list(
      lower = c(0, 0, 0, 0, 0),
      upper = c(1, 1e6, 1e6, 120, 1)
    ),
    target_levels = c("0", "1"),
    output_dir = output_dir,
    silent = TRUE
  )
  passed <- inherits(fit, "dsflower_run") && identical(fit$status, 0L) &&
    isTRUE(fit$available) && file.exists(fit$saved_path)
  if (!passed) stop("dsFlower did not produce a complete model artifact.")

  evidence <- list(
    schema_version = 1L,
    validated_on = format(Sys.Date(), "%Y-%m-%d"),
    demo = "lung1-linked-dslite",
    scope = "engineering systems demonstration; not clinical validation",
    public_dataset = "TCIA NSCLC-Radiomics (LUNG1)",
    site = site,
    cohort_size = "not released by the workflow",
    imaging_metadata_columns = c("sample_id", "patient_id"),
    clinical_table_separate = TRUE,
    radiomics_profile = "aerts_signature",
    radiomics_published = TRUE,
    opaque_feature_view = TRUE,
    privacy_unit = "patient",
    minimum_privacy_units = 10L,
    dp_epsilon_per_training = 1,
    dp_delta_per_training = 1e-6,
    model = "pytorch_logreg",
    rounds = 1L,
    model_artifact_available = TRUE,
    pass = TRUE
  )
  evidence_path <- env(
    "LUNG1_EVIDENCE",
    file.path(workdir, paste0("linked_dslite_evidence_", site, ".json")))
  jsonlite::write_json(
    evidence, evidence_path, auto_unbox = TRUE, pretty = TRUE,
    digits = NA)
  message("LUNG1_LINKED_DSLITE_PASS")
  message("Sanitized evidence: ", evidence_path)
  invisible(evidence)
}

main()
