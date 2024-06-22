#!/usr/bin/env Rscript

# Script to run Diablo (simulate now)
doc <- "This script is to run DIABLO method from mixOmics package.

Usage:
  simple_diablo.R [options]

Options:
  --mae_path=MAE_PATH     Path to read full mae data
  --fold_path=FOLD_PATH   Path to read current test fold
  --prefix=PREFIX         Prefix to read HDF5 [default: pre]
"
# Parase docopt
opt <- docopt::docopt(doc)
library(mixOmics)

separate_Xy <- function(mae) {
  obj <- MultiAssayExperiment::assays(mae)
  # Note need to transpose back to p * n
  X <- lapply(objm as, matrix) |> lapply(t)
  Y <- mae$response
  return(list(X=X, Y=Y))
}

load_MAE <- function(path, prefix="") {
  MAE <- MultiAssayExperiment::loadHDF5MultiAssayExperiment(
      dir     =   train_path,
      prefix  =  paste0("mae_", prefix)
    )
  return(MAE)
}
main <- function(mae_path, fold_path) {
  cat("Looking at this fold:", fold_path)
  train_path <- paste0(fold_path, "_tr")
  test_path <- paste0(fold, path, "_te")
  # Then should read in the MAEs
  train_MAE <- load_MAE(train_path)
  test_MAE <- load_MAE(test_path)
  # Then put this into list
  train_data <- separate_Xy(train_MAE)
  test_data <- separate_Xy(test_MAE)
  # Now I should train on train data and validate it in the test data
  mod <- block.plsda(X = train_data$X, Y = test_data$Y)
  print("Save model to memory")
  saveRDS("diablo_mod.rds")
  predictions <- predict(mod, newdata=test_data)

}

main(mae_path=opt$mae_path, fold_path = opt$fold_path)