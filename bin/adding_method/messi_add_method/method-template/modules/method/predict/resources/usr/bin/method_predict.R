#!/usr/bin/env Rscript

# Script to predict {{ method|lower }} 
doc <- "This script is to make predictions on test data of particular fold, 
using a model trained from the {{ method|lower }} method.

Output type is a path containing the predicted probabilities.

Usage:
  {{ method|lower }}_predict.R [options]

Options:
  --model_path=MODEL_PATH     Path to read the model [default: null]
  --test_path=TEST_PATH       Path containing test data [default: null]
  --label=LABEL               Label of id and fold of data [default: data-fold_i]
  --method_name=METHOD_NAME   Method name input from upstream [default: {{ method|lower }}]
  --output_ext=EXT            Extension of output table to save [default: csv]
"
# Load libraries
library(tibble)
library(magrittr)
library(dplyr)
library(here)
# Source scripts
# This is a helper script to help combine and store results for downstream comparison
source(here("bin/wrangling/get_result_table.R"))
# Parse docopt
opt <- docopt::docopt(doc)
# This is the function logic
# TODO: add suitable args for your method
main <- function(model_path, test_path, label, output_ext, method) {
  # Load model (fit wit train data) and test data of particular fold split
  model <- readRDS(model_path)
  test_data <- readRDS(test_path)
  # Verbose input for debug
  message("\nRead model from ", model_path, "\n")
  message("\nRead test data from ", test_path, "\n")
  # TODO: Implement your logic of getting predicted probabilities of positive class in
  # a binary classification problem
  # Predict and get result
  pred_probs <- predict(model, test_data) # THIS WILL YOU ERROR, so implement this

  # Make sure you could have rownames for identifying different observations/patients
  probs_df <- pred_probs %>%
              as.data.frame() %>%
              rownames_to_column(var="sample_name") %>%
              as_tibble()
  # TODO: might need to transform your output a little to suit this helper function
  # that wrangles and makes it ready for downsteram comparison
  # Merge to summary table
  result_table <- get_result_table(probs=probs_df, label=label, 
                                  method_name=method,
                                  test_data=test_data
                                  )
  
  # Write to files
  message("\nSaving as ", output_ext, " format\n")
  result_file <- paste(label, paste0("result_table", ".", output_ext), sep="-")
  # Save to disk
  write.csv(result_table, result_file, row.names = FALSE)
  return(pred_obj)
}


# Call the function here
main(model_path=opt$model_path, 
     test_path=opt$test_path, 
     label=opt$label,
     output_ext=opt$output_ext,
     method=opt$method
)

message("Done")