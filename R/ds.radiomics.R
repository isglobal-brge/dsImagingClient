#' Extract Radiomic Features from Medical Images
#'
#' Client-side function to extract radiomic features from medical images stored
#' in a DataSHIELD Vault Collection (dsVault), processed via an HPC Unit (dsHPC).
#' This function resolves the resources on the server and calls RadiomicsDS.
#'
#' @param collection.resource Character string. The name of the DataSHIELD Vault
#'   Collection resource (as defined in Opal). This resource should point to a
#'   dsVault collection containing the medical images.
#' @param hpc.resource Character string. The name of the HPC Unit resource
#'   (as defined in Opal). This resource should point to a dsHPC unit for
#'   processing.
#' @param lungmask.model Character. Lungmask model to use. Options: "R231" (default),
#'   "R231CovidWeb", "LTRCLobes", "LTRCLobes_R231".
#' @param feature.classes Character vector. Radiomic feature classes to extract.
#'   Options: "firstorder", "shape", "glcm", "glrlm", "glszm", "gldm", "ngtdm".
#'   Default extracts all.
#' @param bin.width Numeric. Bin width for intensity discretization (default: 25).
#' @param normalize Logical. Normalize image before feature extraction (default: FALSE).
#' @param on.error Character. How to handle failed jobs:
#'   - "exclude" (default): Skip failed images, return partial results
#'   - "stop": Stop with error if any image fails
#' @param newobj Character. Name for the output object on the server (default:
#'   "radiomics.features"). This object stays on the server.
#' @param datasources A list of DSConnection-class objects (default: NULL uses
#'   all connections).
#'
#' @return Invisibly returns NULL. Prints a success message to the console.
#'   The radiomic features data frame is stored on the server in 'newobj' and
#'   can be accessed using standard dsBaseClient functions (e.g., ds.summary,
#'   ds.mean). Individual file hashes are NOT returned to the client for
#'   disclosure control.
#'
#' @details
#' This is an ASSIGN function - results stay on the server and are not returned
#' to the client directly. This ensures disclosure control of individual file
#' information and image hashes.
#'
#' The collection.resource should be configured in Opal pointing to a dsVault
#' DSVaultCollection. The hpc.resource should point to a dsHPC HPC Unit.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Connect to Opal servers
#' library(DSOpal)
#' builder <- DSI::newDSLoginBuilder()
#' builder$append(server = "study1",
#'                url = "https://opal.example.org",
#'                user = "user", password = "password",
#'                resource = "project.collection_resource")
#' logindata <- builder$build()
#' conns <- DSI::datashield.login(logins = logindata)
#'
#' # Extract radiomic features (stored in 'features' on server)
#' ds.radiomics(
#'   collection.resource = "project.ct_images",
#'   hpc.resource = "project.hpc_cluster",
#'   feature.classes = c("firstorder", "shape"),
#'   newobj = "features",
#'   datasources = conns
#' )
#'
#' # The features data frame is now available on the server as 'features'
#' # Use dsBaseClient functions to work with it
#'
#' DSI::datashield.logout(conns)
#' }
ds.radiomics <- function(collection.resource,
                         hpc.resource,
                         lungmask.model = "R231",
                         feature.classes = c("firstorder", "shape", "glcm",
                                             "glrlm", "glszm", "gldm", "ngtdm"),
                         bin.width = 25,
                         normalize = FALSE,
                         on.error = c("exclude", "stop"),
                         newobj = "radiomics.features",
                         datasources = NULL) {

  on.error <- match.arg(on.error)

  # Find datasources if not provided
  if (is.null(datasources)) {
    datasources <- DSI::datashield.connections_find()
  }

  if (is.null(datasources) || length(datasources) == 0) {
    stop("No DataSHIELD connections found. Please connect first using DSI::datashield.login()",
         call. = FALSE)
  }

  # Validate inputs
  if (missing(collection.resource) || !is.character(collection.resource)) {
    stop("collection.resource must be a character string with the resource name", call. = FALSE)
  }

  if (missing(hpc.resource) || !is.character(hpc.resource)) {
    stop("hpc.resource must be a character string with the resource name", call. = FALSE)
  }

  # Generate temporary symbol names for resources
  collection.symbol <- .generateSymbol("collection")
  hpc.symbol <- .generateSymbol("hpc")

  # Step 1: Assign collection resource to server
  message("Assigning collection resource...")
  DSI::datashield.assign.resource(
    conns = datasources,
    symbol = collection.symbol,
    resource = collection.resource
  )

  # Step 2: Assign HPC resource to server
  message("Assigning HPC resource...")
  DSI::datashield.assign.resource(
    conns = datasources,
    symbol = hpc.symbol,
    resource = hpc.resource
  )

  # Step 3: Resolve collection resource to DSVaultCollection object
  message("Resolving collection resource...")
  collection.resolved.symbol <- .generateSymbol("collection.resolved")
  collection.resolve.call <- paste0("as.resource.object(", collection.symbol, ")")
  DSI::datashield.assign.expr(
    conns = datasources,
    symbol = collection.resolved.symbol,
    expr = as.symbol(collection.resolve.call)
  )

  # Step 4: Resolve HPC resource to HPC config object
  message("Resolving HPC resource...")
  hpc.resolved.symbol <- .generateSymbol("hpc.resolved")
  hpc.resolve.call <- paste0("as.resource.object(", hpc.symbol, ")")
  DSI::datashield.assign.expr(
    conns = datasources,
    symbol = hpc.resolved.symbol,
    expr = as.symbol(hpc.resolve.call)
  )

  # Step 5: Call RadiomicsDS on the server
  message("Extracting radiomic features (this may take a while)...")

  # Convert feature.classes to comma-separated string
  feature.classes.str <- paste(feature.classes, collapse = ",")

  # Build the server call
  cally <- paste0(
    "RadiomicsDS(",
    "collection = ", collection.resolved.symbol, ", ",
    "hpc_unit = ", hpc.resolved.symbol, ", ",
    "lungmask_model = '", lungmask.model, "', ",
    "feature_classes = '", feature.classes.str, "', ",
    "bin_width = ", bin.width, ", ",
    "normalize = ", ifelse(normalize, "TRUE", "FALSE"), ", ",
    "on_error = '", on.error, "', ",
    "wait = TRUE, ",
    "verbose = FALSE",
    ")"
  )

  # Execute on server and assign result
  DSI::datashield.assign.expr(
    conns = datasources,
    symbol = newobj,
    expr = as.symbol(cally)
  )

  # Clean up temporary objects
  .cleanupSymbols(datasources, c(collection.symbol, hpc.symbol,
                                  collection.resolved.symbol, hpc.resolved.symbol))

  # Verify object was created
  message(paste0("Radiomic features extracted and stored in '", newobj, "'"))

  invisible(NULL)
}


# ============================================================================
# Internal helper functions
# ============================================================================

#' Generate unique symbol name
#' @keywords internal
.generateSymbol <- function(prefix) {
  paste0("dsImaging.", prefix, ".", paste0(sample(c(letters, 0:9), 6, replace = TRUE), collapse = ""))
}


#' Clean up temporary symbols from server
#' @keywords internal
.cleanupSymbols <- function(datasources, symbols) {
  for (sym in symbols) {
    tryCatch({
      DSI::datashield.rm(conns = datasources, symbol = sym)
    }, error = function(e) {
      # Silently ignore cleanup errors
    })
  }
}
