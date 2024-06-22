logging_write_disk <- function(write_start) {
  end <- Sys.time() - write_start
  cat("\nTime taken write to disk:", round(end, 6), "seconds\n")
  cat("\nData written to disk\n")
  cat(paste(rep("-", 80), collapse = ""))
}

