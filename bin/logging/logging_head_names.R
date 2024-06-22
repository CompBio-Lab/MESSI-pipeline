# Use this to sanity check the rownames and colnames of first n observations, def = 10
logging_head_names <- function(X, n = 10) {
  row_names <- sapply(X, function(x) rownames(x) |> head(n))
  col_names <- sapply(X, function(x) colnames(x) |> head(n))
  cat("Row names:\n")
  cat(row_names, sep = " ")
  cat("\n\nColumn names:\n")
  cat(col_names, sep = " ")
}
