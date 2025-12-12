# =============================================================================
# Test: dsImagingClient with Opal DataSHIELD Server
# =============================================================================
#
# This script tests the full radiomics extraction pipeline through DataSHIELD.
#
# Prerequisites:
#   - Opal server running at localhost:443
#   - Resources configured:
#     - test.images (dsVault collection)
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
# 2. Test ds.image.sync (AGGREGATE) - with single string
# =============================================================================

cat("=== Testing ds.image.sync (single string) ===\n")

tryCatch({
  sync_result <- ds.image.sync(
    collection.resource = "test.images",
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
# 2b. Test ds.image.sync (AGGREGATE) - with named list
# =============================================================================

cat("=== Testing ds.image.sync (named list) ===\n")

tryCatch({
  # Using named list: server_name = "resource_name"
  sync_result <- ds.image.sync(
    collection.resource = list(server = "test.images"),
    hpc.resource = list(server = "test.hpc"),
    datasources = conns
  )

  cat("Sync results (named list):\n")
  for (srv in names(sync_result)) {
    r <- sync_result[[srv]]
    cat(sprintf("  %s: total=%d, existing=%d, uploaded=%d, failed=%d, success=%s\n",
                srv, r$total, r$existing, r$uploaded, r$failed, r$success))
  }
}, error = function(e) {
  cat("Error in ds.image.sync (named list):", conditionMessage(e), "\n")
  tryCatch({
    errors <- DSI::datashield.errors()
    print(errors)
  }, error = function(e2) {})
})

cat("\n")

# =============================================================================
# 3. Test ds.lungmask (AGGREGATE) - with single string
# =============================================================================

cat("=== Testing ds.lungmask (single string) ===\n")

tryCatch({
  lungmask_result <- ds.lungmask(
    collection.resource = "test.images",
    hpc.resource = "test.hpc",
    model = "R231",
    datasources = conns
  )

  cat("Lungmask results:\n")
  for (srv in names(lungmask_result)) {
    r <- lungmask_result[[srv]]
    cat(sprintf("  %s: total=%d, completed=%d, failed=%d, success=%s\n",
                srv, r$total, r$completed, r$failed, r$success))
  }
}, error = function(e) {
  cat("Error in ds.lungmask:", conditionMessage(e), "\n")
  tryCatch({
    errors <- DSI::datashield.errors()
    print(errors)
  }, error = function(e2) {})
})

cat("\n")

# =============================================================================
# 3b. Test ds.lungmask (AGGREGATE) - with named list
# =============================================================================

cat("=== Testing ds.lungmask (named list) ===\n")

tryCatch({
  lungmask_result <- ds.lungmask(
    collection.resource = list(server = "test.images"),
    hpc.resource = list(server = "test.hpc"),
    model = "R231",
    datasources = conns
  )

  cat("Lungmask results (named list):\n")
  for (srv in names(lungmask_result)) {
    r <- lungmask_result[[srv]]
    cat(sprintf("  %s: total=%d, completed=%d, failed=%d, success=%s\n",
                srv, r$total, r$completed, r$failed, r$success))
  }
}, error = function(e) {
  cat("Error in ds.lungmask (named list):", conditionMessage(e), "\n")
  tryCatch({
    errors <- DSI::datashield.errors()
    print(errors)
  }, error = function(e2) {})
})

cat("\n")

# =============================================================================
# 4. Test ds.radiomics (ASSIGN) - with single string
# =============================================================================

cat("=== Testing ds.radiomics (single string) ===\n")

tryCatch({
  ds.radiomics(
    collection.resource = "test.images",
    hpc.resource = "test.hpc",
    lungmask.model = "R231",
    feature.classes = c("firstorder", "shape"),
    bin.width = 25,
    normalize = FALSE,
    on.error = "exclude",
    newobj = "features",
    datasources = conns
  )

  cat("Radiomics extraction complete! Features stored in 'features' on server.\n")

  # Check the result using dsBaseClient
  cat("\nChecking result dimensions...\n")
  dims <- dsBaseClient::ds.dim("features", datasources = conns)
  for (srv in names(dims)) {
    cat(sprintf("  %s: %d rows x %d columns\n", srv, dims[[srv]][1], dims[[srv]][2]))
  }

  # Get column names
  cat("\nFeature columns (first 10):\n")
  colnames_result <- dsBaseClient::ds.colnames("features", datasources = conns)
  for (srv in names(colnames_result)) {
    cols <- colnames_result[[srv]]
    cat(sprintf("  %s: %s...\n", srv, paste(head(cols, 10), collapse = ", ")))
  }

}, error = function(e) {
  cat("Error in ds.radiomics:", conditionMessage(e), "\n")
  tryCatch({
    errors <- DSI::datashield.errors()
    print(errors)
  }, error = function(e2) {})
})

cat("\n")

# =============================================================================
# 4b. Test ds.radiomics (ASSIGN) - with named list
# =============================================================================

cat("=== Testing ds.radiomics (named list) ===\n")

tryCatch({
  ds.radiomics(
    collection.resource = list(server = "test.images"),
    hpc.resource = list(server = "test.hpc"),
    lungmask.model = "R231",
    feature.classes = c("firstorder", "shape"),
    bin.width = 25,
    normalize = FALSE,
    on.error = "exclude",
    newobj = "features_named",
    datasources = conns
  )

  cat("Radiomics extraction complete (named list)!\n")
  cat("Features stored in 'features_named' on server.\n")

  # Check the result
  dims <- dsBaseClient::ds.dim("features_named", datasources = conns)
  for (srv in names(dims)) {
    cat(sprintf("  %s: %d rows x %d columns\n", srv, dims[[srv]][1], dims[[srv]][2]))
  }

}, error = function(e) {
  cat("Error in ds.radiomics (named list):", conditionMessage(e), "\n")
  tryCatch({
    errors <- DSI::datashield.errors()
    print(errors)
  }, error = function(e2) {})
})

# =============================================================================
# 5. Cleanup
# =============================================================================

cat("\n=== Disconnecting ===\n")
DSI::datashield.logout(conns)
cat("Done!\n")
