# Preprocess raw matrices by center and scale
preprocess_dat <- function(mat, method=c("center", "scale")) {
  preprocessed_values <- caret::preProcess(mat, method=method)
  output_mat <- predict(preprocessed_values, mat)
  return(output_mat)
}
