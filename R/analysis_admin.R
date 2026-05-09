# Module: Admin Functions for Model Management
# Protected by the same admin_key as dsJobs admin methods.

#' Install a segmentation model on the server (admin only)
#'
#' Downloads model weights to the hospital's server. Requires admin_key
#' to be configured: dsadmin.set_option(con, "dsjobs.admin_key", "secret")
#'
#' @param conns DSI connections object.
#' @param admin_key Character; the admin key.
#' @param provider Character; "totalsegmentator", "lungmask", "monai", "nnunetv2".
#' @param task Character; model/task name (e.g. "total", "R231").
#' @return Named list with install status per server.
#' @export
ds.imaging.install_model <- function(conns, admin_key, provider, task) {
  key_enc <- .ds_encode(list(.admin_key = admin_key))
  results <- .ds_safe_aggregate(conns,
    expr = call("imagingInstallModelDS", key_enc, provider, task))
  for (srv in names(results)) {
    r <- results[[srv]]
    if (identical(r$status, "installed"))
      cat("  ", srv, ": installed", provider, task, "\n")
    else
      cat("  ", srv, ": FAILED -", r$error %||% "unknown", "\n")
  }
  invisible(results)
}

#' List installed models on the server
#'
#' @param conns DSI connections object.
#' @return Named list with per-server model listings.
#' @export
ds.imaging.models <- function(conns) {
  .ds_safe_aggregate(conns,
    expr = call("imagingListModelsDS"))
}
