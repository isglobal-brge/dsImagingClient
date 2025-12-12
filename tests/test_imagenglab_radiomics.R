# =============================================================================
# Test: Radiomics extraction from ImagEngLab COVID-19 dataset
# =============================================================================
#
# Prerequisites:
#   - Opal server running at localhost:443
#   - Resources configured:
#     - test.imagenglab (dsVault collection with COVID CT scans)
#     - test.hpc (dsHPC API endpoint)
#   - dsImaging package installed on server
#
# =============================================================================

library(DSI)
library(dsBaseClient)
library(DSOpal)
library(dsImagingClient)
library(httr)
 
# Disable SSL verification (no certificate on local Opal)
httr::set_config(httr::config(ssl_verifypeer = 0L, ssl_verifyhost = 0L))

# =============================================================================
# 1. Connect to Opal
# =============================================================================

cat("=== Connecting to Opal server ===\n")

builder <- DSI::newDSLoginBuilder()
builder$append(
  server = "server",
  url = "https://localhost:443",
  user = "administrator",
  password = "password"
)
logindata <- builder$build()

conns <- DSI::datashield.login(logins = logindata)

cat("Connected successfully!\n")
cat("Connections:", names(conns), "\n\n")

# =============================================================================
# 2. Sync images to HPC first
# =============================================================================

cat("=== Syncing ImagEngLab COVID images to HPC ===\n")

tryCatch({
  sync_result <- ds.image.sync(
    collection.resource = "test.imagenglab",
    hpc.resource = "test.hpc",
    datasources = conns
  )

  cat("Sync results:\n")
  for (srv in names(sync_result)) {
    r <- sync_result[[srv]]
    cat(sprintf("  %s: total=%d, existing=%d, uploaded=%d, failed=%d, success=%s\n",
                srv, r$total, r$existing, r$uploaded, r$failed, r$success))
  }
}, error = function(e) {
  cat("Error in ds.image.sync:", conditionMessage(e), "\n")
  tryCatch({
    errors <- DSI::datashield.errors()
    print(errors)
  }, error = function(e2) {})
})

cat("\n")

# =============================================================================
# 3. Extract radiomic features with COVID-optimized model
# =============================================================================

cat("=== Extracting radiomic features (R231CovidWeb model) ===\n")
cat("This will take a while for 81 CT scans...\n\n")

tryCatch({
  ds.radiomics(
    collection.resource = "test.imagenglab",
    hpc.resource = "test.hpc",
    lungmask.model = "R231CovidWeb",  # COVID-optimized lung segmentation
    feature.classes = c("firstorder", "shape", "glcm"),  # Core features
    bin.width = 25,
    normalize = FALSE,
    on.error = "exclude",
    newobj = "covid_features",
    datasources = conns
  )

  cat("Radiomics extraction complete!\n")
  cat("Features stored in 'covid_features' on server.\n\n")

  # Check dimensions
  cat("Checking result dimensions...\n")
  dims <- dsBaseClient::ds.dim("covid_features", datasources = conns)
  for (srv in names(dims)) {
    cat(sprintf("  %s: %d rows x %d columns\n", srv, dims[[srv]][1], dims[[srv]][2]))
  }

  # Get column names
  cat("\nFeature columns (first 15):\n")
  colnames_result <- dsBaseClient::ds.colnames("covid_features", datasources = conns)
  for (srv in names(colnames_result)) {
    cols <- colnames_result[[srv]]
    cat(sprintf("  %s: %s...\n", srv, paste(head(cols, 15), collapse = ", ")))
    cat(sprintf("  Total columns: %d\n", length(cols)))
  }

  # Quick summary of first few features
  cat("\n=== Sample feature statistics ===\n")

  # Get class of the object to verify it's a data frame
  class_result <- dsBaseClient::ds.class("covid_features", datasources = conns)
  cat("Object class:", class_result[[1]], "\n")

}, error = function(e) {
  cat("Error in ds.radiomics:", conditionMessage(e), "\n")
  tryCatch({
    errors <- DSI::datashield.errors()
    print(errors)
  }, error = function(e2) {})
})

# =============================================================================
# 4. Cleanup
# =============================================================================

cat("\n=== Disconnecting ===\n")
DSI::datashield.logout(conns)
cat("Done!\n")
