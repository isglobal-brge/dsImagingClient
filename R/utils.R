# ============================================================================
# Internal helper functions for dsImagingClient
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


#' Resolve resource name for a specific server
#'
#' @description
#' Internal helper to resolve resource names that can be either:
#' - A character string (same name for all servers)
#' - A named list (different names per server)
#'
#' @param resource Character string or named list of resource names
#' @param server_name Name of the server to resolve for
#' @param resource_type Type of resource (for error messages)
#'
#' @return Character string with the resource name for the server
#' @keywords internal
.resolveResourceName <- function(resource, server_name, resource_type = "resource") {
  if (is.character(resource) && length(resource) == 1) {
    # Single string: use same name for all servers
    return(resource)
  } else if (is.list(resource) && !is.null(names(resource))) {
    # Named list: look up server-specific name
    if (server_name %in% names(resource)) {
      return(resource[[server_name]])
    } else {
      stop(paste0("No ", resource_type, " name specified for server '", server_name, "'. ",
                  "Available servers in resource: ", paste(names(resource), collapse = ", ")),
           call. = FALSE)
    }
  } else {
    stop(paste0(resource_type, " must be either a character string or a named list"),
         call. = FALSE)
  }
}


#' Validate resource parameter
#'
#' @description
#' Validates that a resource parameter is either a non-empty string or a named list
#'
#' @param resource The resource parameter to validate
#' @param param_name Name of the parameter (for error messages)
#'
#' @return TRUE if valid (invisibly), otherwise throws an error
#' @keywords internal
.validateResourceParam <- function(resource, param_name) {
  if (missing(resource) || is.null(resource)) {
    stop(paste0(param_name, " is required"), call. = FALSE)
  }

  if (is.character(resource)) {
    if (length(resource) != 1 || nchar(resource) == 0) {
      stop(paste0(param_name, " must be a non-empty character string or a named list"),
           call. = FALSE)
    }
  } else if (is.list(resource)) {
    if (is.null(names(resource)) || any(names(resource) == "")) {
      stop(paste0(param_name, " as a list must have names (server names)"),
           call. = FALSE)
    }
    if (!all(sapply(resource, is.character))) {
      stop(paste0(param_name, " list values must be character strings"),
           call. = FALSE)
    }
  } else {
    stop(paste0(param_name, " must be a character string or a named list"),
         call. = FALSE)
  }

  invisible(TRUE)
}


#' Assign resources per server with support for named lists
#'
#' @description
#' Assigns resources to servers, handling both single string (same for all)
#' and named list (per-server) resource specifications.
#'
#' @param datasources List of DSConnection objects
#' @param symbol Symbol name to assign to
#' @param resource Character string or named list of resource names
#' @param resource_type Type of resource (for error messages)
#'
#' @keywords internal
.assignResourcePerServer <- function(datasources, symbol, resource, resource_type = "resource") {
  server_names <- names(datasources)

  for (server_name in server_names) {
    resource_name <- .resolveResourceName(resource, server_name, resource_type)

    DSI::datashield.assign.resource(
      conns = datasources[server_name],
      symbol = symbol,
      resource = resource_name
    )
  }
}
