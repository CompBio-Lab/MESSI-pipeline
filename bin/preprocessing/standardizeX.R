# Preprocessing
# Helper functions to have right X and Y argument for model
standardizeX <- function(X) {
  # Note need to transpose back to p * n
  X_out <- X |> 
    lapply(t) |> 
    lapply(as.matrix)
  return(X_out)
}
