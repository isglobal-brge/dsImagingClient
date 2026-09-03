# Module: Client Utilities

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Run a DataSHIELD transport without deparsed expressions or remote errors
#'
#' DSI may print the full call expression when progress reporting is enabled.
#' Imaging calls carry opaque handles and base64-encoded workflow requests, so
#' both global diagnostic options are disabled only for the transport call and
#' restored even when it fails.
#' @keywords internal
.with_quiet_datashield_transport <- function(code) {
  previous <- options(
    datashield.progress = FALSE,
    datashield.errors.print = FALSE,
    progress_enabled = FALSE)
  on.exit(options(previous), add = TRUE)
  force(code)
}

#' Validate the retained compatibility argument for analytical workflows.
#'
#' Workflow visibility is enforced as private by dsImaging. Global publication
#' is an administrator operation and is not available through DataSHIELD.
#' @keywords internal
.require_private_workflow_visibility <- function(visibility) {
  if (!is.character(visibility) || length(visibility) != 1L ||
      is.na(visibility) || !identical(visibility, "private")) {
    stop("Analytical imaging workflows are always private.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Compute a derivation hash (client-side copy)
#'
#' Identical to dsImaging::compute_derivation_hash but avoids pulling
#' the full dsImaging dependency (arrow, aws.s3, DBI, etc.) into the
#' client installation.
#' @keywords internal
.compute_derivation_hash <- function(...) {
  params <- list(...)
  params <- params[order(names(params))]
  blob <- jsonlite::toJSON(params, auto_unbox = TRUE, digits = 10)
  digest::digest(blob, algo = "sha256", serialize = FALSE)
}

#' Encode R objects as URL-safe B64 JSON for DataSHIELD transport
#'
#' @keywords internal
.ds_encode <- function(x) {
  json <- as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null"))
  b64 <- gsub("[\r\n]", "", jsonlite::base64_enc(charToRaw(json)))
  b64 <- gsub("\\+", "-", b64)
  b64 <- gsub("/", "_", b64)
  b64 <- gsub("=+$", "", b64)
  paste0("B64:", b64)
}

#' Generate a server-side symbol for domain workflow handles
#' @keywords internal
.generate_symbol <- function(prefix = "dsIjob") {
  symbol <- paste0(prefix, ".",
    paste(sample(c(letters, LETTERS, 0:9), 12, replace = TRUE), collapse = ""))
  .imaging_validate_symbol(symbol)
}

#' Assign a high-level imaging workflow request to the server
#' @keywords internal
.assign_domain_workflow <- function(conns, method, request, symbol = NULL) {
  symbol <- symbol %||% .generate_symbol()
  .imaging_require_symbol_absent(conns, symbol)
  request$handle <- request$handle %||% "img"
  encoded <- .ds_encode(request)
  assigned <- FALSE
  on.exit({
    if (!assigned) {
      rollback <- tryCatch(
        .imaging_workflow_rollback(conns, symbol),
        error = function(e) list(
          failures = paste0("rollback-state[", conditionMessage(e), "]")))
      if (length(rollback$failures)) {
        tryCatch(
          warning(
            "dsImaging workflow rollback was incomplete on: ",
            paste(rollback$failures, collapse = ", "),
            ". Retry ds.imaging.workflow.destroy(conns, workflow = ",
            deparse(symbol), ").",
            call. = FALSE),
          error = function(e) NULL)
      }
    }
  }, add = TRUE)
  .imaging_assign_exact(conns, "dsImaging workflow assignment",
    function(success, error) {
      DSI::datashield.assign.expr(
        conns, symbol = symbol, expr = call(method, encoded),
        success = success, error = error, errors.print = FALSE)
    })
  assigned <- TRUE
  out <- list(
    symbol = symbol,
    method = method,
    handle = request$handle,
    dataset_id = request$dataset_id %||% NULL,
    label = "dsImaging",
    servers = if (inherits(conns, "DSConnection")) "default" else names(conns),
    submitted_at = Sys.time()
  )
  class(out) <- c("dsimaging_domain_submission", "list")
  out
}

#' @keywords internal
.imaging_workflow_symbol <- function(workflow) {
  symbol <- if (inherits(workflow, "dsimaging_domain_submission")) {
    workflow$symbol
  } else {
    workflow
  }
  if (!is.character(symbol) || length(symbol) != 1L || is.na(symbol) ||
      !grepl("^[A-Za-z][A-Za-z0-9._]{0,127}$", symbol)) {
    stop("A valid dsImaging workflow symbol is required.", call. = FALSE)
  }
  symbol
}

#' Exact rollback for a partially assigned workflow
#' @keywords internal
.imaging_workflow_rollback <- function(conns, symbol) {
  .imaging_destroy_exact(conns, symbol, "imagingWorkflowDestroyDS")
}

#' Resilient datashield.aggregate that tolerates per-server failures
#'
#' @param conns DSI connections object.
#' @param expr A call expression, or a method name with arguments in `...`.
#' @param ... Arguments used when `expr` is a method name.
#' @return Named list of results.
#' @keywords internal
.ds_safe_aggregate <- function(conns, expr, ...) {
  if (is.character(expr)) {
    expr <- as.call(c(list(as.name(expr)), list(...)))
  }

  server_names <- if (inherits(conns, "DSConnection")) "default" else names(conns)
  results <- list()
  errors <- list()
  for (srv in server_names) {
    tryCatch({
      res <- .with_quiet_datashield_transport(
        DSI::datashield.aggregate(
          if (srv == "default") conns else conns[srv],
          expr = expr))
      results[[srv]] <- if (srv == "default") {
        res
      } else if (is.list(res) && srv %in% names(res)) {
        res[[srv]]
      } else {
        res
      }
    }, error = function(e) {
      # Remote conditions can contain node paths, storage URIs, sample ids, or
      # backend diagnostics. Retain only which configured node failed.
      errors[[srv]] <<- "remote aggregate call failed"
    })
  }
  # Surface per-server failures at call time; they are also kept in the
  # "ds_errors" attribute for programmatic access (.ds_first_result and
  # dsHPCClient's print method render it).
  for (srv in names(errors)) {
    warning("dsImaging remote aggregate call failed on server '", srv, "'.",
            call. = FALSE)
  }
  if (length(errors) > 0) {
    attr(results, "ds_errors") <- errors
  }
  results
}

#' Return the first server result or fail with collected DataSHIELD errors
#'
#' @keywords internal
.ds_first_result <- function(results, context = "DataSHIELD call") {
  if (length(results) == 0) {
    errors <- attr(results, "ds_errors")
    detail <- if (length(errors) > 0) {
      paste(paste(names(errors), unlist(errors), sep = ": "),
        collapse = "; ")
    } else {
      "no server returned a result"
    }
    stop(context, " failed: ", detail, call. = FALSE)
  }
  srv <- names(results)[1]
  result <- results[[srv]]
  if (is.null(result)) {
    stop(context, " failed on server ", srv, call. = FALSE)
  }
  result
}
