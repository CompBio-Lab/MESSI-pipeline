# Use this to sanity check the rownames and colnames of first n observations, def = 10
logging_head_names <- function(X, n = 10) {
  stopifnot(is.list(X))
  cat("===== DEBUG: matrix row/column names =====\n")
  for (nm in names(X)) {
    cat("\n---", nm, "---\n")
    x <- X[[nm]]
    if (!is.matrix(x)) {
      cat("  [WARN] Not a matrix\n")
      next
    }
    rn <- rownames(x)
    cn <- colnames(x)
    cat("  Rows (head):\n")
    if (is.null(rn)) {
      cat("    <NULL>\n")
    } else {
      cat("    ", head(rn, n), "\n")
    }
    cat("  Cols (head):\n")
    if (is.null(cn)) {
      cat("    <NULL>\n")
    } else {
      cat("    ", head(cn, n), "\n")
    }
  }
  cat("\n===== END DEBUG =====\n")
}
