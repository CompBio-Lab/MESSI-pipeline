# Tune coop hyperparameters
source(here::here("modules/R/generic_helpers/saveFile.R"))
tune_coop <- function(data, type.measure, rho, folds=10, verbose=FALSE) {
  if (verbose) {
    trace.it <- TRUE
    cat("\nSet verbose, you will see progress bar for cv\n")
  } else {
    trace.it <- FALSE
  }
  cat("\nStarting to tune hypeparameters with cv\n")
  tuned_model <- multiview::cv.multiview(x_list = data$X, y = data$Y, 
                                         family = binomial(),
                                         type.measure = type.measure, 
                                         rho = rho, nfolds=folds, 
                                         trace.it = trace.it)
  cat("\nFinished tuning\n")
  cat("\nWriting tuned object to file\n")
  saveFile(object = tuned_model, name="coop_tuned_model", ext=".rds")
  cat("\nFinished writing tuned object to file\n")
  return(tuned_model)
}
