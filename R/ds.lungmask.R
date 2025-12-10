#' Run Lungmask Segmentation
#'
#' Client-side function to run lung segmentation on medical images using
#' lungmask. Returns aggregate status for disclosure control - no individual
#' file or hash information is returned.
#'
#' @param collection.resource Character string or named list. The name of the
#'   DataSHIELD Vault Collection resource (as defined in Opal). Can be either:
#'   - A single character string (same resource name for all servers)
#'   - A named list with server names as keys and resource names as values
#' @param hpc.resource Character string or named list. The name of the HPC Unit
#'   resource (as defined in Opal). Same format as collection.resource.
#' @param model Character. Lungmask model to use. Options: "R231" (default),
#'   "R231CovidWeb", "LTRCLobes", "LTRCLobes_R231".
#' @param timeout Numeric. Maximum wait time in seconds (default: 600).
#' @param datasources A list of DSConnection-class objects.
#'
#' @return A list (per server) with aggregate status:
#'   - total: Total images processed
#'   - completed: Successfully processed
#'   - failed: Failed to process
#'   - success: TRUE if no failures
#'
#' @details
#' This is an AGGREGATE function - it returns only safe aggregate counts to
#' the client. Individual file names, hashes, and mask results stay on the
#' server for disclosure control.
#'
#' The function internally syncs images to HPC if needed before running
#' lungmask segmentation. GPU acceleration is used automatically if available
#' on the HPC server.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Option 1: Same resource name for all servers
#' status <- ds.lungmask(
#'   collection.resource = "project.vault",
#'   hpc.resource = "project.hpc",
#'   model = "R231",
#'   datasources = conns
#' )
#'
#' # Option 2: Different resource names per server
#' status <- ds.lungmask(
#'   collection.resource = list(
#'     study1 = "radiology.images",
#'     study2 = "imaging.ct_scans"
#'   ),
#'   hpc.resource = list(
#'     study1 = "compute.hpc",
#'     study2 = "infra.cluster"
#'   ),
#'   model = "R231",
#'   datasources = conns
#' )
#'
#' # Check status
#' status$study1$total      # Total images
#' status$study1$completed  # Successful
#' status$study1$success    # TRUE if all succeeded
#' }
ds.lungmask <- function(collection.resource,
                        hpc.resource,
                        model = "R231",
                        timeout = 600,
                        datasources = NULL) {

  # Find datasources
  if (is.null(datasources)) {
    datasources <- DSI::datashield.connections_find()
  }

  if (is.null(datasources) || length(datasources) == 0) {
    stop("No DataSHIELD connections found", call. = FALSE)
  }

  # Validate inputs (supports both string and named list)
  .validateResourceParam(collection.resource, "collection.resource")
  .validateResourceParam(hpc.resource, "hpc.resource")

  # Validate model
  valid.models <- c("R231", "R231CovidWeb", "LTRCLobes", "LTRCLobes_R231")
  if (!model %in% valid.models) {
    stop(paste0("Invalid model. Must be one of: ",
                paste(valid.models, collapse = ", ")),
         call. = FALSE)
  }

  # Generate temporary symbols
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

  # Call LungmaskDS as AGGREGATE (returns status, not assigns)
  message("Running lungmask segmentation (this may take a while)...")
  cally <- paste0(
    "LungmaskDS(",
    "collection = ", collection.resolved, ", ",
    "hpc_unit = ", hpc.resolved, ", ",
    "model = '", model, "', ",
    "timeout = ", timeout,
    ")"
  )

  result <- DSI::datashield.aggregate(
    conns = datasources,
    expr = as.symbol(cally)
  )

  # Cleanup
  .cleanupSymbols(datasources, c(collection.symbol, hpc.symbol,
                                 collection.resolved, hpc.resolved))

  # Print summary
  for (server in names(result)) {
    status <- result[[server]]
    message(sprintf("[%s] Lungmask: %d total, %d completed, %d failed",
                    server, status$total, status$completed, status$failed))
  }

  return(result)
}
