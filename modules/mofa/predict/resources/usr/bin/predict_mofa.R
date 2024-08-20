#!/usr/bin/env Rscript

# Script to run mofa predictions
doc <- "This script is to make predictions on test data of particular fold, 
using a model trained with MOFA from MOFA2 package and its embeddings with glmnet.

Output type is a path containing the predicted probabilities

Usage:
  predict_mofa.R [options]

Options:
  --model_path=MODEL_PATH   Path to read the model [default: null]
  --test_path=TEST_PATH     Path containing test data [default: null]
  --label=LABEL             Label of id and fold of data [default: data-fold_i]
  --output_ext=EXT          Extension of output table to save [default: csv]
"

library(here)
library(MOFA2)
library(glmnet)
library(magrittr)
library(dplyr)
# Load script

# Gather the pipeline dir (THIS IS VERY UGGLY FIX)
bin_dir <- Sys.getenv("PATH") |> 
  strsplit(":") |>
  unlist() |>
  tail(1)
pipeline_dir <- gsub("/bin", "", bin_dir)

source(here(pipeline_dir, "bin/wrangling/get_result_table.R"))
# Parse docopt
opt <- docopt::docopt(doc)

# Default to use AveragedPredict and max.dist
main <- function(model_path, test_path, label, output_ext, method_name="mofa",
                digit = 3, s = 0) {
  # Load model (from same fold train portion)
  model <- readRDS(model_path)
  # Load test data (from same fold test portion)
  test_data <- readRDS(test_path) # NOTE here data is n x p
  test_x <- test_data$X$embeddings
  # Then make predictions using the previous glmnet model
  predictions <- stats::predict(
    object=model,
    s = s,
    newx = test_x,
    type = "response"
    ) |> as.numeric()
  # Join this intermediate result pred prob of P(Y=1)
  
  pred_probs <- data.frame(sample_name = rownames(test_x), phat = predictions)
  # Merge to summary table
  # matching by sample names inside the data
  result_table <- get_result_table(probs=pred_probs, label=label, 
                                  method_name=method_name, 
                                  test_data=test_data, digit=digit
                                  )
  # Write to files
  cat("\nSaving as", output_ext, "format\n")
  result_file <- paste(label, paste0("result_table", ".", output_ext), sep="-")
  # Save to disk
  write.csv(result_table, result_file, row.names = FALSE)
  return(pred_probs)
}


# Call the function here
main(model_path=opt$model_path, 
     test_path=opt$test_path, 
     label=opt$label,
     output_ext=opt$output_ext
     )

cat("Done")