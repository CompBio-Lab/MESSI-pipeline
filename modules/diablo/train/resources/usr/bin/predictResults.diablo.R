library(mixOmics)
# Predict to get y hats based on dist
predictResults.diablo <- function(mod, newdata, dist, ...) {
  cat("\nPredicting results\n")
  if (is.null(dist)) {
    cat("dist not found, using default")
    dist <- "centroids.dist"
  }
  cat("\nUsing", dist, "as distance\n")
  # NOTE this X refers to X block (that should contain >= 2 matrices)
  predicted <- predict(mod, newdata=newdata$X, ...)
  cat("\nFinished predictions\n")
  # For now just look at weighted votes
  results <- predicted$WeightedVote[[dist]][,1] |> as.factor()
  return(results)
}