#!/usr/bin/env Rscript

# Script to run Diablo (simulate now)
doc <- "This script is to run DIABLO method from mixOmics package, train only
it could possibly be ran on a inner CV mode, output is a model for prediction
usage in downstream.

Usage:
  simple_diablo.R [options]

Options:
  --mae_path=MAE_PATH     Path to read full mae data
  --fold_path=FOLD_PATH   Path to read current test fold
  --prefix=PREFIX         Prefix to read HDF5 [default: pre]
  --inner_cv              Run inner cv with train data or not [default: false]     
"
# Parase docopt
opt <- docopt::docopt(doc)
library(mixOmics)
library(here)
library(MultiAssayExperiment)
library(stringr)


all_folds <- list.files(here("results/diablo_preprocess/sample1"), pattern = 'test',full.names = TRUE)
fold_path <- all_folds[2]

inner_cv = FALSE

separate_Xy <- function(mae) {
  # Note need to transpose back to p * n
  # TODO: add check for dimension match
  X <- mae@ExperimentList@listData |> lapply(t)
  Y <- mae$response
  return(list(X=X, Y=Y))
}

load_MAE <- function(path, prefix="") {
  MAE <- loadHDF5MultiAssayExperiment(
    dir     =  path,
    prefix  =  prefix
  )
  return(MAE)
}

#   true_label <- true_label
# pred <- predict(mod, newdata=test_data$X)$WeightedPredict.classs$max.dist[, max(mod$ncomp)]

main <- function(mae_path, fold_path, inner_cv) {
  cat("\nLooking at this fold:", fold_path, "\n")
  d <- list.files(path=fold_path, full.names = TRUE)
  train_path <- d[str_detect(d, pattern = "_tr")]
  # Then should read in the MAE and convert it to list of X and Y
  train_data <- load_MAE(train_path, "train") |> separate_Xy()
  # Train a model mode to run inner cv or not
  if (inner_cv) {
    cat("\nTraining with inner cv per single fold, this could take more time\n")
    mod <- "A"
  } else {
    cat("\nNot running inner cv per fold\n")
    mod <- block.plsda(X = train_data$X, Y = train_data$Y)  
  }
  # Create label to denote id/fold_i
  label <- fold_path %>%
       str_split(pattern = "/") %>%
       unlist() %>% 
       tail(2) %>%
       paste(collapse="/")
  # Filenames to write out
  mod_file <- "diablo_mod.rds"
  weight_file <-  "mod_weights.txt"
  cat("\nSaving files to", label, "\n")
  # Write out
  saveRDS(object = mod, mod_file)
  write.table(x = mod$weights, weight_file)
  return(mod)
}

m <- main(mae_path = "", fold_path = fold_path, inner_cv=inner_cv)
#main(mae_path=opt$mae_path, fold_path = opt$fold_path)