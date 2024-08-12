#!/usr/bin/env Rscript

# Script to run Diablo (simulate now)
doc <- "This script is to make predictions on test data of particular fold, 
using a model trained with DIABLO from mixOmics package.

Output type is a path containing the predicted probabilities

Usage:
  predict_diablo.R [options]

Options:
  --model_path=MODEL_PATH   Path to read the model [default: null]
  --test_path=TEST_PATH     Path containing test data [default: null]
  --label=LABEL             Label of id and fold of data [default: data-fold_i]
  --output_ext=EXT          Extension of output table to save [default: csv]
  --design=DESIGN           Connection choice of design matrix [default: full]
"

library(here)
library(mixOmics)
library(magrittr)
library(dplyr)
# Load script
source(here("bin/wrangling/get_result_table.R"))
# Parse docopt
opt <- docopt::docopt(doc)

# Default to use AveragedPredict and max.dist
main <- function(model_path, test_path, label, design, output_ext, method_name="diablo",
                 pred = "AveragedPredict", dist = "max.dist", digit = 3, rename_chr=FALSE) {

  # Parameters
  # Load model (from same fold train portion)
  model <- readRDS(model_path)
  # Load test data (from same fold test portion)
  test_data <- readRDS(test_path)
  # Append the design choice to the method name
  #method_name <- paste0(method_name, "-", model$call$design)
  method_name <- paste0(method_name, "-", design)
  
  pred_class <- paste0(pred, ".class")
  cat("\nRead model from", model_path, "\n")
  cat("\nRead test data from", test_path, "\n")
  # Other parameters to use
  ncomp <- max(model$ncomp) # Take largest number of component
  dim <- paste0("dim", ncomp) # This is the dimension of predicted vals to get
  # Predict and get result by max of ncomp
  # TODO: This needs a more unified way from upstream to
  #       have all use binary 01 or just character yes no  
  if ("yes" %in% model$names$colnames$Y) {
    rename_chr <- TRUE
  }
  pred_obj <- predict(model, newdata = test_data$X)
  # Gather true labels, and predicted labels, probability, weights
  # This is always 3 columns, sample_name is first
  pred_probs <- pred_obj[[pred]][, , dim] %>%
    as.data.frame() %>%
    tibble::rownames_to_column(var = "sample_name")
  # TODO: this bit is very bad and hardcoded .....
  if (rename_chr) {
    pred_probs <- pred_probs %>%
      dplyr::rename(
        phat = yes,
        phat_no = no
      )
      #dplyr::select(-no)
  } else {
    pred_probs <- pred_probs %>%
      dplyr::rename(
        phat = "1",
        phat_no = "0"
      )
      #dplyr::select(-"0")
  }
  # TODO: This might not be a good fix, make sure to update the phat to use a absolute value
  # since it might give you negative value sometimes?

  # The coefficient weights
  weights <- pred_obj$weights %>% round(digits = digit)
  # Merge to summary table
  # matching by sample names inside the data
  result_table <- get_result_table(probs=pred_probs, label=label, 
                                  method_name=method_name, 
                                  test_data=test_data, digit=digit
                                  )
  # Write to files
  cat("\nSaving as", output_ext, "format\n")
  result_file <- paste(label, paste0("result_table.", output_ext), sep="-")
  weight_file <- paste(label, paste0("block_weight.", output_ext), sep="-")
  # Save to disk
  write.csv(result_table, result_file, row.names = FALSE)
  write.table(weights, weight_file)
  return(pred_obj)
}


# Call the function here
main(model_path=opt$model_path, 
     test_path=opt$test_path, 
     label=opt$label,
     output_ext=opt$output_ext,
     design=opt$design
     )

cat("Done")