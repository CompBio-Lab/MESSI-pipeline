getDesign <- function(X, corr=0.1) {
  cat("\nGenerating design matrix\n")
  if (is.null(corr)) {
    cat("Could not find corr, using default")
    corr <- 0.1
    
  }
  if (corr > 1) {
    cat("Correlation between blocks should be <= 1, using default 0.1")
    corr <- 0.1
  }
  # for square matrix filled with 0.1s, diag 0
  design <- matrix(
		corr, ncol = length(X), nrow = length(X), 
		dimnames = list(names(X), names(X))
		)
  diag(design) <- 0
  cat("\nGenerated design matrix\n")
  return(design)
}
