#!/usr/bin/env Rscript

# Script to train caret_multimodal model
doc <- "This script is to run caret_multimodal method, run it only against the train MAE from previously
processed data. Output is the path to this trained model and the test MAE.

Usage:
 caret_multimodal_train.R [options]

Options:
 --fold_path=FOLD_PATH Path to read current test fold
 --label=LABEL Label of id and fold of data [default: data]
 --prefix=PREFIX Prefix to read HDF5 [default: pre]
 --run_inner_cv Run inner cv with train data or not [default: false]
 --method_name=METHOD_NAME Name of the method [default: caret_multimodal]
"


# Load libraries
library(dplyr)
library(here)
library(MultiAssayExperiment)
library(stringr)
library(caret)
# Load scripts ========================================================
# Gather the pipeline dir (THIS IS VERY UGGLY FIX)
bin_dir <- Sys.getenv("PATH") |>
 strsplit(":") |>
 unlist() |>
 tail(1)

# Determine if running on cluster deploy mode or local mode
is_scratch <- stringr::str_detect(bin_dir, pattern = "scratch")
if (is_scratch) {
 pipeline_dir <- gsub("/bin", "", bin_dir)
} else {
 pipeline_dir <- ""
}


# Source custom functions
source(here(pipeline_dir, "bin/rhelpers.R")) # This is included in nextflow bin path
# Loading generic utils from directories
load_utils(here(pipeline_dir, "bin/logging"))
load_utils(here(pipeline_dir, "bin/misc_utils"))
load_utils(here(pipeline_dir, "bin/plotting"))
# Parse docopt
opt <- docopt::docopt(doc)

# Stacking helpers ====================================================

# Save the objects needed to reproduce/debug a caret_stack failure.
# Returns the normalized path of the debug file.
.save_stack_debug <- function(base_models, target, tuneGrid, trControl,
                              error_msg, label) {
 debug_file <- paste0(label, "-caret_stack_debug.rds")
 saveRDS(
 list(
 base_models = base_models,
 target = target,
 tuneGrid = tuneGrid,
 trControl = trControl,
 rng_state = .Random.seed,
 error = error_msg
 ),
 file = debug_file
 )
 normalizePath(debug_file, mustWork = FALSE)
}

# glmnet refuses exactly zero-variance predictors (C++ error 7777), which is
# what happens when the base models carry no signal: caret selects a
# degenerate intercept-only lambda, the OOF predictions become constant, and
# the stack glmnet crashes -> caret stops with "Stopping".
#
# caret_stack() recomputes its OOF features from the base models' stored
# `pred` data frames, so we nudge constant class-probability columns there by
# a tiny deterministic offset (+/- epsilon, no RNG involved). Only the
# probability columns are touched -- never alpha/lambda, which caret uses as
# join keys when extracting the best-tune predictions.
#
# Returns list(base_models, nudged_columns).
.nudge_constant_oof <- function(base_models, epsilon = 1e-6) {
 nudged_cols <- character(0)
   for (i in seq_along(base_models)) {
   m <- base_models[[i]]
   p <- m$pred
   prob_cols <- intersect(m$levels, names(p))
   const_cols <- prob_cols[vapply(
   prob_cols,
   function(cl) length(unique(p[[cl]])) == 1,
   logical(1)
   )]
   if (length(const_cols)) {
   nudge <- rep(c(-1, 1), length.out = nrow(p)) * epsilon
   for (cl in const_cols) {
   p[[cl]] <- p[[cl]] + nudge
   }
   base_models[[i]]$pred <- p
   nudged_cols <- c(nudged_cols, paste0(names(base_models)[i], ".", const_cols))
   }
   }
   list(base_models = base_models, nudged_columns = nudged_cols)
}

# Fit the stacked model with a safety net for no-signal data:
# 1st attempt: plain caret_stack (the normal path, unchanged).
# On error:    save debug objects, nudge constant OOF columns, retry
#              caret_stack itself, and tag the result with a
#              `stack_fallback` attribute so retried folds can be
#              identified downstream.
# If the retry also fails, stop with a message pointing to the debug file.
.stack_with_fallback <- function(base_models, tuneGrid, trControl, target, label) {
 stack_model <- tryCatch(
   {
   caretMultimodal::caret_stack(
   caret_list = base_models,
   method = "glmnet",
   tuneGrid = tuneGrid,
   trControl = trControl
   )
   },
   error = function(e) {
   debug_file <- .save_stack_debug(
   base_models = base_models,
   target = target,
   tuneGrid = tuneGrid,
   trControl = trControl,
   error_msg = conditionMessage(e),
   label = label
   )

   nudged <- .nudge_constant_oof(base_models)

   retried <- tryCatch(
   {
   caretMultimodal::caret_stack(
   caret_list = nudged$base_models,
   method = "glmnet",
   tuneGrid = tuneGrid,
   trControl = trControl
   )
   },
   error = function(e2) {
   stop(
   "Stacking failed again after nudging constant OOF predictions: ",
   conditionMessage(e2),
   "\nDebug objects saved to: ", debug_file,
   call. = FALSE
   )
   }
   )

   attr(retried, "stack_fallback") <- list(
   reason = conditionMessage(e),
   nudged_columns = nudged$nudged_columns,
   debug_file = debug_file
   )

   warning(
   "\nStacking failed: ", conditionMessage(e),
   "\nRetried caret_stack on nudged (near-constant) OOF predictions.",
   "\nDebug objects saved to: ", debug_file
   )

   retried
   }
   )
   stack_model
}

# Training ============================================================

train_model <- function(train_data, label = "data", inner_cv = FALSE) {
 #alphas <- c(0.7, 0.775, 0.850, 0.925, 1)
 #lambdas <- seq(0.001, 0.1, by = 0.01)
 alphas <- c(0) # Ridge regression only, no Lasso or elastic-net, since we have many features and want to keep them all
 lambdas <- 10^seq(-4, 3, length = 20) # Use log space lambda values
 tuneGrid <- expand.grid(alpha = alphas, lambda = lambdas)
 # Caret relies on tuneGrid and trainControl for hyperparameter tuning
 if (inner_cv) {
 trControl <- trainControl(
   method = "repeatedcv",
   number = 5,
   repeats = 3,
   classProbs = TRUE,
   summaryFunction = twoClassSummary,
   savePredictions = "final"
 )

 } else {
 # Default with no inner cv, simple train-test
 trControl <- trainControl(
   method = "cv",
   number = 5, # This is internal cv for tuning the hyperparameters, not the same as the outer cv fold split, which is done by nextflow
   classProbs = TRUE,
   summaryFunction = twoClassSummary,
   savePredictions = "final"
 )
 }




 # =========================================================
 # First fit individual models for each modality
 base_models <- caretMultimodal::caret_list(
   target = train_data$Y,
   data_list = train_data$X,
   method = "glmnet",
   tuneGrid = tuneGrid,
   trControl = trControl
 )
 message("\nFinished fitting base models for each modality, now stacking them together...")

 # Then fit the ensemble model (with a retry safety net for no-signal data)
 stack_model <- .stack_with_fallback(
   base_models = base_models,
   tuneGrid = tuneGrid,
   trControl = trControl,
   target = train_data$Y,
   label = label
 )

 message("\nFinished fitting the stacked model.")
 return(stack_model)
}

get_seed <- function(dataset_name) {
 d_int <- utf8ToInt(dataset_name) # Convert dataset name to integer
 # For caretMultimodal only, add a "hacky" constant to the seed to make it different from other methods
 # As it could go into problem with internal cv splitting when parallized run
 seed <- sum(d_int) + 1
 message("\nSeed used: ", seed)
 return(seed)
}

# Main function to run
main <- function(fold_path, label, prefix, method_name, inner_cv=FALSE) {
 seed <- get_seed(label) # Set seed based on dataset name for reproducibility
 set.seed(seed)
 # Log the params used
 args_used <- c(as.list(environment()))
 logging_params(args_used)
 cat("\nLooking at this fold: ", fold_path, "\n")
 # Finds the subdirectories containing tr and te MAE
 d <- list.files(path=fold_path, full.names = TRUE)
 train_path <- d[str_detect(d, pattern = "_tr")]
 test_path <- d[str_detect(d, pattern = "_te")]
 # Then should read in the MAE and convert it to list of X and Y
 # This converts usual MAE format of p_i x N to N x p_i
 train_data <- load_MAE(train_path, prefix="train") |> extract_Xy(verbose_target=TRUE)
 test_data <- load_MAE(test_path, prefix="test") |> extract_Xy(verbose_target=TRUE)
 sample_names <- check_common_samples(train_data)
 # Sanity check for debugging
 cat("\nTotal of", length(sample_names), "samples:\n", sample_names)
 # Train the model here
 model <- train_model(train_data, label = label, inner_cv = inner_cv)
 if (is.null(model)) {
  stop("Model did not implement yet, model is NULL")
 }

 # Filenames to write out
 model_file <- paste(label, paste(method_name, "model.rds", sep = "_"), sep = "-")
 test_file <- paste(label, "test_data.rds", sep = "-")
 cat("\nSaving files to", label, "\n")
 # Write out to disk
 saveRDS(object = model, model_file)
 saveRDS(object = test_data, test_file)
 return(model)
}


# Call the function here
main(
 fold_path = opt$fold_path,
 label = opt$label,
 prefix = opt$prefix,
 method_name = opt$method_name,
 inner_cv = as.logical(opt$run_inner_cv)
)
cat("Done")
