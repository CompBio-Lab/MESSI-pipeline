# # Script to run Diablo (simulate now)
# "This script is to run DIABLO method from mixOmics package.
# 
# Usage:
#   R_run_diablo.R [options]
# 
# Options:
#     --train_path=<train_path>     Path to read train data
#     --test_path=<test_path>   Path to read test data
#     --prefix=<prefix>         Prefix to read HDF5 [default: pre]
# " -> doc
# 
# opt <- docopt::docopt(doc)
source(here::here("modules/R/generic_helpers.R"))
load_helpers(helper_path = "modules/R/classification/diablo/helpers")
library(mixOmics)
library(dplyr)
# model func
train_path <- "/arc_data/splitTrainTest/data/sample8/sample8-train_data.rds"
test_path <- "/arc_data/splitTrainTest/data/sample8/sample8-test_data.rds"
prefix <- ""
ext <- ".rds"
corr <- 0.1
#dist = c("centroids.dist", "max.dist", "mahalanobis.dist")
dist <- "centroids.dist"
validation <- "Mfold"
folds <- nrepeat <- 10
init_ncomp <- 5
# Main entrance of the script
main <- function(train_path, test_path, prefix, 
                 corr=0.1, 
                 init_ncomp = 5,
                 dist = c("centroids.dist", "max.dist", "mahalanobis.dist"),
                 validation = "Mfold",
                 folds = 10,
                 nrepeat = 10,
                 ext=".rds") {
  # Log the params used
  args_used <- c(as.list(environment()))
  logging_params(args_used)
  #---------------------------------------------------------------------------
  dist <- match.arg(dist)
  #---------------------------------------------------------------------------
  # Data goes here
  data <- getData(train_path, test_path=test_path, 
                  prefix=prefix, ext = ext)
  X <- data$X
  Y <- data$Y

  #---------------------------------------------------------------------------
  # Train a base model (With high initial ncomp of 5)
  base_model <- mixOmics::block.splsda(X = X , Y = Y)
  #---------------------------------------------------------------------------
  # Design matrix, with diagonals 0, rest 0.1 (default)
  design <- getDesign(X = X)
  # run component number tuning with repeated CV
  tuned_output <- tune_diablo(base_model = base_model, validation = validation, 
                          folds=folds, nrepeat=nrepeat, design=design, dist=dist)
  # Train the final model
  final_model <- mixOmics::block.splsda(X = X, Y = Y, 
                                       ncomp = tuned_output$ncomp, 
                                       keepX = tuned_output$keepX, design = design)
  #---------------------------------------------------------------------------
  # Predict on 'newdata'
  base_prediction <- predictResults.diablo(mod = base_model, newdata=data$newdata,
                                       dist=dist)  
  
  final_prediction <- predictResults.diablo(mod=final_model, newdata = data$newdata, 
                                      dist=dist)
  
  base_prediction
  final_prediction
  cat("\nSaving predictions to file\n")
  savePred(base_prediction)
  savePred(final_prediction, "prediction.rds")
  cat("\nSaved predictions\n")
  return(final_model)
}

set.seed(329)
main(train_path = train_path, 
     test_path=test_path,
     prefix = prefix
)


base_model$design

base_model
final_model
# ------------------------------------------------------------

# - genGrid has extra last val to be total numebr of features 

# ------------------------------------------------------------

# Test some stuff here
base_results <- predictResults(base_model, newdata=data$newdata, dist=dist)
opt_results <- predictResults(final_model, newdata=data$newdata, dist=dist)
actual_y <- data$newdata$Y
df <- tibble(actual = actual_y, base = base_results, optimal = opt_results)
library(caret)

base_conf <- caret::confusionMatrix(df$base , df$actual)
opt_conf <- caret::confusionMatrix(df$optimal, df$actual)

base_conf
opt_conf


