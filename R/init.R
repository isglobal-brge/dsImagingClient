# Module: Imaging Dataset Initialization

#' Initialize Imaging Dataset Handle
#'
#' Assigns an imaging resource on each server and creates an imaging
#' handle via \code{imagingInitDS()}.
#'
#' @param conns DSI connections object.
#' @param resource Character; name of the Opal or Armadillo Resource to assign.
#' @param symbol Character; symbol name for the imaging handle
#'   (default \code{"img"}).
#' @return \code{TRUE}, invisibly. The initialized imaging object remains on
#'   every server under \code{symbol} for imaging operations or independent
#'   downstream consumers.
#' @examples
#' \dontrun{
#' # conns <- DSI::datashield.login(...)  # live DataSHIELD session
#' ds.imaging.init(conns, resource = "lung_ct_res", symbol = "img")
#' ds.imaging.metadata(conns, "img")
#' }
#' @export
ds.imaging.init <- function(conns, resource, symbol = "img") {
  resource_symbol <- .imaging_init_resource_symbol(symbol)
  provider_transients <- c("R", "rds")
  temporary_symbols <- c(provider_transients, resource_symbol)
  .imaging_require_symbol_absent(conns, c(symbol, temporary_symbols))
  initialized <- FALSE
  init_attempted <- FALSE
  on.exit({
    cleanup_failures <- character()
    if (init_attempted && !initialized) {
      rollback <- tryCatch(
        .imaging_destroy_exact(conns, symbol, "imagingDestroyDS"),
        error = function(e) list(
          failures = paste0("handle-state[", conditionMessage(e), "]")))
      cleanup_failures <- c(cleanup_failures, rollback$failures)
    }
    for (temporary in temporary_symbols) {
      cleanup <- tryCatch(
        .imaging_remove_symbol_exact(conns, temporary),
        error = function(e) list(
          failures = paste0("temporary-state[", conditionMessage(e), "]")))
      cleanup_failures <- c(cleanup_failures, cleanup$failures)
    }
    if (length(cleanup_failures)) {
      tryCatch(
        warning(
          "dsImaging initialization cleanup was incomplete on: ",
          paste(unique(cleanup_failures), collapse = ", "),
          ". Retained handles or temporary resources can be retried with ",
          "ds.imaging.destroy(conns, ",
          "symbol = ", deparse(symbol), ").",
          call. = FALSE),
        error = function(e) NULL)
    }
  }, add = TRUE)

  .imaging_assign_exact(conns, "Resource assignment", function(success, error) {
    DSI::datashield.assign.resource(
      conns, symbol = resource_symbol, resource = resource,
      success = success, error = error, errors.print = FALSE)
  })

  # imagingInitDS takes the resource SYMBOL NAME, validates the complete
  # patient roster, and returns only an opaque session-bound handle.
  init_attempted <- TRUE
  .imaging_assign_exact(conns, "dsImaging privacy admission",
    function(success, error) {
      DSI::datashield.assign.expr(
        conns, symbol = symbol, expr = call("imagingInitDS", resource_symbol),
        success = success, error = error, errors.print = FALSE)
    })

  cleanup_failures <- unlist(lapply(temporary_symbols, function(temporary) {
    .imaging_remove_symbol_exact(conns, temporary)$failures
  }), use.names = FALSE)
  if (length(cleanup_failures)) {
    stop("Temporary imaging resource cleanup failed on: ",
      paste(unique(cleanup_failures), collapse = ", "), ".", call. = FALSE)
  }
  initialized <- TRUE

  invisible(TRUE)
}

#' Destroy an Imaging Dataset Handle
#'
#' Removes an initialized imaging handle, its private session registry entry,
#' and the deterministic temporary resource symbol used by
#' \code{ds.imaging.init()}. This also makes the function the documented retry
#' path when initialization succeeded remotely but temporary-resource removal
#' could not be confirmed. Dataset objects in the backing store are not changed.
#'
#' @param conns DSI connections object.
#' @param symbol Character; initialized imaging handle (default \code{"img"}).
#' @return \code{TRUE}, invisibly.
#' @export
ds.imaging.destroy <- function(conns, symbol = "img") {
  report <- .imaging_destroy_exact(conns, symbol, "imagingDestroyDS")
  resource_report <- .imaging_remove_symbol_exact(
    conns, .imaging_init_resource_symbol(symbol))
  resource_failures <- sub(
    "^([^:]+):(.+)$", "\\1:resource[\\2]", resource_report$failures)
  failures <- c(report$failures, resource_failures)
  if (length(failures)) {
    stop("dsImaging handle or temporary-resource destruction failed on: ",
      paste(failures, collapse = ", "), ". Successful or already ",
      "absent nodes were skipped; uncertain symbols were kept for retry. ",
      "Retry ds.imaging.destroy(conns, symbol = ", deparse(symbol), ").",
      call. = FALSE)
  }
  invisible(TRUE)
}

# Deterministic so ds.imaging.destroy() can recover a temporary resource after
# both the in-band removal and on.exit retry fail. The prefix is protocol-owned;
# the digest keeps every valid caller handle within DataSHIELD's symbol limit.
.imaging_init_resource_symbol <- function(symbol) {
  symbol <- .imaging_validate_symbol(symbol)
  paste0("dsIres.", substr(digest::digest(
    paste0("dsImagingClient:init-resource:", symbol),
    algo = "sha256", serialize = FALSE), 1L, 32L))
}

.imaging_validate_symbol <- function(symbol) {
  if (!is.character(symbol) || length(symbol) != 1L || is.na(symbol) ||
      !grepl("^[A-Za-z][A-Za-z0-9._]{0,127}$", symbol)) {
    stop("A visible DataSHIELD symbol beginning with a letter is required.",
      call. = FALSE)
  }
  symbol
}

.imaging_require_symbol_absent <- function(conns, symbol) {
  symbol <- unique(vapply(symbol, .imaging_validate_symbol, character(1)))
  observed <- tryCatch(DSI::datashield.symbols(conns), error = function(e) NULL)
  hosts <- names(conns)
  if (is.null(observed) || !length(hosts) ||
      !all(hosts %in% names(observed))) {
    stop("Could not verify that the target DataSHIELD symbol is unused.",
      call. = FALSE)
  }
  occupied <- hosts[vapply(hosts, function(host) {
    any(symbol %in% as.character(observed[[host]]))
  }, logical(1))]
  if (length(occupied)) {
    stop("Target DataSHIELD symbol already exists on: ",
      paste(occupied, collapse = ", "), ". Remove it or choose another symbol.",
      call. = FALSE)
  }
  invisible(TRUE)
}

.imaging_node_symbols_exact <- function(conns, host) {
  observed <- tryCatch(
    DSI::datashield.symbols(conns[host]), error = identity)
  if (inherits(observed, "error") || !is.list(observed) ||
      !identical(names(observed), host) || is.null(observed[[host]])) {
    return(list(ok = FALSE))
  }
  symbols <- as.character(observed[[host]])
  if (anyNA(symbols)) return(list(ok = FALSE))
  list(ok = TRUE, symbols = symbols)
}

.imaging_remove_symbol_exact <- function(conns, symbol) {
  symbol <- .imaging_validate_symbol(symbol)
  hosts <- names(conns)
  if (!length(hosts) || anyNA(hosts) || any(!nzchar(hosts)) ||
      anyDuplicated(hosts)) {
    stop("DataSHIELD connections require non-empty, unique node names.",
      call. = FALSE)
  }
  failures <- character()
  per_site <- stats::setNames(vector("list", length(hosts)), hosts)
  for (host in hosts) {
    before <- .imaging_node_symbols_exact(conns, host)
    if (!isTRUE(before$ok)) {
      failures <- c(failures, paste0(host, ":symbol-state"))
      per_site[[host]] <- list(state = "uncertain")
      next
    }
    if (!symbol %in% before$symbols) {
      per_site[[host]] <- list(state = "absent")
      next
    }
    remove_error <- tryCatch({
      DSI::datashield.rm(conns[host], symbol)
      NULL
    }, error = identity)
    after <- .imaging_node_symbols_exact(conns, host)
    if (is.null(remove_error) && isTRUE(after$ok) &&
        !symbol %in% after$symbols) {
      per_site[[host]] <- list(state = "removed")
    } else {
      failures <- c(failures, paste0(host, ":remove"))
      per_site[[host]] <- list(state = "retained")
    }
  }
  list(per_site = per_site, failures = unique(failures))
}

.imaging_destroy_exact <- function(conns, symbol, method) {
  symbol <- .imaging_validate_symbol(symbol)
  if (!is.character(method) || length(method) != 1L || is.na(method) ||
      !method %in% c(
        "imagingDestroyDS", "imagingWorkflowDestroyDS",
        "imagingFeatureViewDestroyDS")) {
    stop("Unknown dsImaging destroy method.", call. = FALSE)
  }
  hosts <- names(conns)
  if (!length(hosts) || anyNA(hosts) || any(!nzchar(hosts)) ||
      anyDuplicated(hosts)) {
    stop("DataSHIELD connections require non-empty, unique node names.",
      call. = FALSE)
  }

  failures <- character()
  per_site <- stats::setNames(vector("list", length(hosts)), hosts)
  for (host in hosts) {
    before <- .imaging_node_symbols_exact(conns, host)
    if (!isTRUE(before$ok)) {
      failures <- c(failures, paste0(host, ":symbol-state"))
      per_site[[host]] <- list(state = "uncertain", destroy_ack = NA)
      next
    }
    if (!symbol %in% before$symbols) {
      per_site[[host]] <- list(state = "absent", destroy_ack = NA)
      next
    }

    destroy_error <- tryCatch({
      .imaging_assign_exact(conns[host], "dsImaging destruction",
        function(success, error) {
          DSI::datashield.assign.expr(
            conns[host], symbol = symbol, expr = call(method, symbol),
            success = success, error = error, errors.print = FALSE)
        })
      NULL
    }, error = identity)
    if (!is.null(destroy_error)) {
      failures <- c(failures, paste0(host, ":destroy"))
      per_site[[host]] <- list(state = "retained", destroy_ack = FALSE)
      next
    }

    removed <- .imaging_remove_symbol_exact(conns[host], symbol)
    if (length(removed$failures)) {
      failures <- c(failures, paste0(host, ":remove"))
      per_site[[host]] <- list(state = "retained", destroy_ack = TRUE)
    } else {
      per_site[[host]] <- list(state = "destroyed", destroy_ack = TRUE)
    }
  }
  list(per_site = per_site, failures = unique(failures))
}

# Require an explicit successful callback from every DataSHIELD node.
.imaging_assign_exact <- function(conns, operation, invoke) {
  hosts <- names(conns)
  if (!length(hosts) || anyNA(hosts) || any(!nzchar(hosts)) ||
      anyDuplicated(hosts)) {
    stop("DataSHIELD connections require non-empty, unique node names.",
      call. = FALSE)
  }
  succeeded <- stats::setNames(rep(FALSE, length(hosts)), hosts)
  failed <- stats::setNames(rep(FALSE, length(hosts)), hosts)
  invalid_callback <- FALSE
  success <- function(node, ...) {
    if (length(node) != 1L || is.na(node) || !node %in% hosts) {
      invalid_callback <<- TRUE
    } else {
      succeeded[[node]] <<- TRUE
    }
  }
  error <- function(node, ...) {
    if (length(node) != 1L || is.na(node) || !node %in% hosts) {
      invalid_callback <<- TRUE
    } else {
      failed[[node]] <<- TRUE
    }
  }
  thrown <- tryCatch({
    .with_quiet_datashield_transport(invoke(success, error))
    NULL
  }, error = identity)
  bad <- hosts[!succeeded | failed]
  if (!is.null(thrown) || invalid_callback || length(bad)) {
    if (!length(bad)) bad <- hosts
    stop(operation, " failed or returned no ACK on: ",
      paste(bad, collapse = ", "), ".", call. = FALSE)
  }
  invisible(TRUE)
}
