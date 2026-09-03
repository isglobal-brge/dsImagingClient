# Module: Content Hash Injection
#
# Resource identity is established by an initialized imaging handle. The client
# does not query content hashes directly from DataSHIELD servers.

#' Resolve a resource content hash through an explicitly configured resolver
#' @keywords internal
.resolve_content_hash <- function(conns, resource_name) {
  resolver <- getOption("dsimagingclient.content_hash_resolver", NULL)
  server_names <- .content_hash_server_names(conns)
  if (is.function(resolver)) {
    return(.normalize_content_hash_result(
      resolver(conns, resource_name), server_names))
  }

  stats::setNames(rep(NA_character_, length(server_names)), server_names)
}

#' @keywords internal
.content_hash_server_names <- function(conns) {
  if (inherits(conns, "DSConnection")) return("default")
  nms <- names(conns)
  if (!is.null(nms) && length(nms) > 0L && all(nzchar(nms))) return(nms)
  "default"
}

#' @keywords internal
.normalize_content_hash_result <- function(value, server_names) {
  out <- stats::setNames(rep(NA_character_, length(server_names)), server_names)
  if (is.null(value)) return(out)

  if (is.list(value) && !is.null(value$content_hash)) {
    if (!identical(value$source %||% NA_character_, "unsupported") &&
        !is.na(value$content_hash) && nzchar(value$content_hash)) {
      out[] <- as.character(value$content_hash)
    }
    return(out)
  }

  value <- unlist(value, use.names = TRUE)
  if (length(value) == 0L) return(out)
  value <- as.character(value)

  if (is.null(names(value)) || !any(nzchar(names(value)))) {
    out[seq_len(min(length(out), length(value)))] <- value[
      seq_len(min(length(out), length(value)))]
  } else {
    common <- intersect(names(out), names(value))
    out[common] <- value[common]
  }
  out[is.na(out) | !nzchar(out)] <- NA_character_
  out
}

#' @keywords internal
.submit_imaging_job <- function(conns, job) {
  if (is.list(job) && !is.null(job$domain_method)) {
    method <- job$domain_method
    job$domain_method <- NULL
    return(.assign_domain_workflow(conns, method, job))
  }
  stop("Low-level dsHPC job submission from dsImagingClient is deprecated. ",
    "Use a ds.imaging.* workflow that invokes a dsImaging DataSHIELD method.",
    call. = FALSE)
}

#' @keywords internal
.enrich_imaging_job_resources <- function(conns, job) {
  resources <- .collect_job_resource_names(job)
  if (length(resources) == 0L) return(job)

  records <- list()
  for (resource_name in resources) {
    hashes <- .resolve_content_hash(conns, resource_name)
    available <- hashes[!is.na(hashes) & nzchar(hashes)]
    if (length(available) == 0L) next
    records[[resource_name]] <- list(
      name = resource_name,
      content_hash = unname(available[[1]]),
      by_server = as.list(available)
    )
  }
  if (length(records) == 0L) return(job)

  job <- .enrich_resource_fields(job, records)
  job$content_hashes <- records
  if (is.list(job$steps)) {
    for (i in seq_along(job$steps)) {
      step_resources <- intersect(.collect_job_resource_names(job$steps[[i]]),
        names(records))
      if (length(step_resources) > 0L) {
        job$steps[[i]]$resource_hashes <- records[step_resources]
      }
    }
  }
  job
}

#' @keywords internal
.collect_job_resource_names <- function(x) {
  fields <- c("resource", "dataset_id", "image_asset", "mask_asset",
    "mask_b_asset", "reference_asset", "dicom_asset", "rt_asset",
    "dose_asset", "plan_asset", "wsi_asset")
  out <- character(0)

  walk <- function(value, field = "") {
    if (is.list(value)) {
      if (identical(field, "resource") && !is.null(value$name) &&
          is.character(value$name) && length(value$name) == 1L) {
        out <<- c(out, value$name)
      }
      nms <- names(value)
      for (i in seq_along(value)) {
        child_name <- if (!is.null(nms) && nzchar(nms[i])) nms[i] else ""
        walk(value[[i]], child_name)
      }
      return(invisible(NULL))
    }
    if (field %in% fields && is.character(value) && length(value) == 1L &&
        !is.na(value) && nzchar(value)) {
      out <<- c(out, value)
    }
    invisible(NULL)
  }

  walk(x)
  unique(out)
}

#' @keywords internal
.enrich_resource_fields <- function(x, records) {
  if (!is.list(x)) return(x)
  nms <- names(x)
  for (i in seq_along(x)) {
    field <- if (!is.null(nms) && nzchar(nms[i])) nms[i] else ""
    if (identical(field, "resource")) {
      x[i] <- list(.enrich_resource_reference(x[[i]], records))
    } else {
      x[i] <- list(.enrich_resource_fields(x[[i]], records))
    }
  }
  x
}

#' @keywords internal
.enrich_resource_reference <- function(ref, records) {
  if (is.character(ref) && length(ref) == 1L && ref %in% names(records)) {
    return(records[[ref]])
  }
  if (is.list(ref) && !is.null(ref$name) && ref$name %in% names(records) &&
      is.null(ref$content_hash)) {
    record <- records[[ref$name]]
    ref$content_hash <- record$content_hash
    ref$by_server <- record$by_server
  }
  ref
}
