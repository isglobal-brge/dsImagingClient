# Module: Radiomics Summary

#' Print a summary of radiomics activity
#' @param conns DSI connections object.
#' @export
ds.imaging.summary <- function(conns) {
  cat("=== dsImaging Summary ===\n\n")

  # Jobs
  jobs <- ds.imaging.jobs(conns)
  for (srv in names(jobs$per_site)) {
    df <- jobs$per_site[[srv]]
    cat("-- ", srv, " ", paste(rep("-", 40), collapse = ""), "\n", sep = "")
    if (!is.data.frame(df) || nrow(df) == 0) {
      cat("  No radiomics jobs\n\n")
      next
    }
    states <- table(df$state)
    cat("  Jobs:", nrow(df))
    for (s in names(states)) cat(" |", s, ":", states[s])
    cat("\n")
    for (i in seq_len(min(nrow(df), 10))) {
      cat("  ", df$state[i], " ", df$progress[i], " ",
          df$submitted_at[i], "\n")
    }
    cat("\n")
  }
  invisible(jobs)
}
