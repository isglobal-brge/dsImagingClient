# Module: Client Utilities

`%||%` <- function(x, y) if (is.null(x)) y else x

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

#' Generate a client-side job id for domain-mediated dsHPC submissions
#' @keywords internal
.generate_job_id <- function() {
  paste0("job_", paste(sample(c(letters, 0:9), 32, replace = TRUE), collapse = ""))
}

#' Generate a server-side symbol for domain workflow handles
#' @keywords internal
.generate_symbol <- function(prefix = "dsIjob") {
  paste0(prefix, ".",
    paste(sample(c(letters, LETTERS, 0:9), 6, replace = TRUE), collapse = ""))
}

#' Assign a high-level imaging workflow request to the server
#' @keywords internal
.assign_domain_workflow <- function(conns, method, request, symbol = NULL) {
  symbol <- symbol %||% .generate_symbol()
  encoded <- .ds_encode(request)
  DSI::datashield.assign.expr(conns, symbol = symbol, expr = call(method, encoded))
  out <- list(
    symbol = symbol,
    method = method,
    job_id = request$job_id %||% NULL,
    dataset_id = request$dataset_id %||% NULL,
    label = "dsImaging",
    servers = if (inherits(conns, "DSConnection")) "default" else names(conns),
    submitted_at = Sys.time()
  )
  class(out) <- c("dsimaging_domain_submission", "list")
  out
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
      res <- DSI::datashield.aggregate(
        if (srv == "default") conns else conns[srv],
        expr = expr)
      results[[srv]] <- if (srv == "default") {
        res
      } else if (is.list(res) && srv %in% names(res)) {
        res[[srv]]
      } else {
        res
      }
    }, error = function(e) {
      errors[[srv]] <<- e$message
    })
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
