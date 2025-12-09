#' Sync Vault Images to HPC Storage
#'
#' Client-side function to synchronize medical images from a DataSHIELD Vault
#' Collection (dsVault) to HPC storage. Returns aggregate sync status for
#' disclosure control - no individual file information is returned.
#'
#' @param collection.resource Character string or named list. The name of the
#'   DataSHIELD Vault Collection resource (as defined in Opal). Can be either:
#'   - A single character string (same resource name for all servers)
#'   - A named list with server names as keys and resource names as values
#' @param hpc.resource Character string or named list. The name of the HPC Unit
#'   resource (as defined in Opal). Same format as collection.resource.
#' @param datasources A list of DSConnection-class objects (default: NULL uses
#'   all connections).
#'
#' @return A list (per server) with aggregate sync status:
#'   - total: Total files in vault
#'   - existing: Files already in HPC
#'   - uploaded: Files uploaded this run
#'   - failed: Files that failed to upload
#'   - success: TRUE if no failures
#'
#' @details
#' This is an AGGREGATE function - it returns only safe aggregate counts to
#' the client. Individual file names and hashes stay on the server for
#' disclosure control.
#'
#' The collection.resource should be configured in Opal pointing to a dsVault
#' DSVaultCollection. The hpc.resource should point to a dsHPC HPC Unit.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Connect to Opal
#' conns <- DSI::datashield.login(...)
#'
#' # Option 1: Same resource name for all servers
#' status <- ds.image.sync(
#'   collection.resource = "project.vault_images",
#'   hpc.resource = "project.hpc_cluster",
#'   datasources = conns
#' )
#'
#' # Option 2: Different resource names per server
#' status <- ds.image.sync(
#'   collection.resource = list(
#'     study1 = "radiology.images",
#'     study2 = "imaging.ct_scans"
#'   ),
#'   hpc.resource = list(
#'     study1 = "compute.hpc",
#'     study2 = "infra.cluster"
#'   ),
#'   datasources = conns
#' )
#'
#' # Check status
#' status$study1$total     # Total files
#' status$study1$uploaded  # Files uploaded
#' status$study1$success   # TRUE if all succeeded
#' }
ds.image.sync <- function(collection.resource,
                          hpc.resource,
                          datasources = NULL) {

  # Find datasources if not provided
  if (is.null(datasources)) {
    datasources <- DSI::datashield.connections_find()
  }

  if (is.null(datasources) || length(datasources) == 0) {
    stop("No DataSHIELD connections found. Please connect first.",
         call. = FALSE)
  }

  # Validate inputs (supports both string and named list)
  .validateResourceParam(collection.resource, "collection.resource")
  .validateResourceParam(hpc.resource, "hpc.resource")

  # Generate temporary symbol names
  collection.symbol <- .generateSymbol("collection")
  hpc.symbol <- .generateSymbol("hpc")

  # Assign resources (per-server if named list)
  message("Assigning resources...")
  .assignResourcePerServer(
    datasources, collection.symbol, collection.resource, "collection.resource"
  )
  .assignResourcePerServer(
    datasources, hpc.symbol, hpc.resource, "hpc.resource"
  )

  # Resolve resources
  collection.resolved <- .generateSymbol("collection.resolved")
  hpc.resolved <- .generateSymbol("hpc.resolved")

  DSI::datashield.assign.expr(
    conns = datasources,
    symbol = collection.resolved,
    expr = as.symbol(paste0("as.resource.object(", collection.symbol, ")"))
  )

  DSI::datashield.assign.expr(
    conns = datasources,
    symbol = hpc.resolved,
    expr = as.symbol(paste0("as.resource.object(", hpc.symbol, ")"))
  )

  # Call ImageSyncDS as AGGREGATE (returns status, not assigns)
  message("Syncing images to HPC...")
  cally <- paste0(
    "ImageSyncDS(",
    "collection = ", collection.resolved, ", ",
    "hpc_unit = ", hpc.resolved,
    ")"
  )

  result <- DSI::datashield.aggregate(
    conns = datasources,
    expr = as.symbol(cally)
  )

  # Cleanup temporary objects
  .cleanupSymbols(datasources, c(collection.symbol, hpc.symbol,
                                 collection.resolved, hpc.resolved))

  # Print summary
  for (server in names(result)) {
    status <- result[[server]]
    message(sprintf("[%s] Sync: %d total, %d uploaded, %d existing, %d failed",
                    server, status$total, status$uploaded,
                    status$existing, status$failed))
  }

  return(result)
}
