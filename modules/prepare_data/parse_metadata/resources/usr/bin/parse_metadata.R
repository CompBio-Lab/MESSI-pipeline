#!/usr/bin/env Rscript
doc <- "
This script is used to read processed datasets (could have simulated data)
and parse their simple metadata

Author: Tony Liang

Usage:
  parse_metadata.R [options]

Options:
  --mae_path_list=MAE_PATH_LIST   Path to the MultiAssayExperiment [default: empty]
"

# Parse cli args
opt <- docopt::docopt(doc)

# Load libraries
library(MultiAssayExperiment)
library(here)
library(dplyr)

parseMeta2df <- function(mae, dataset_name=NULL, simulated_dname="sim_data") {
  if (is.null(dataset_name)) stop("Did not provide a dataset name for current mae data")
  # Create the dataframe
  # Each row should be a dataset
  output_df <- data.frame(dataset_name = dataset_name)
  # Now get various information from the mae
  omics_names <- names(mae@ExperimentList) |> paste(collapse=",")
  row_dims <- sapply(mae@ExperimentList, nrow) |> paste(collapse = ",")
  col_dims <- sapply(mae@ExperimentList, ncol) |> paste(collapse = ",")
  # Also parse based on the dataset name to see if it was a simulated
  is_simulated <- ifelse(stringr::str_detect(dataset_name, pattern=simulated_dname), 1 , 0)

  # TODO: need a more robust code on parsing the metadata
  response <- mae@metadata$response
  is_binary_chr_factor <- is.factor(response) && length(levels(response)) == 2
  if (!is_binary_chr_factor) {
    # TODO: this is for regression purpose response
    message("Should not come to this branch for parsing response to df")
  } else {
    # Then should count those of response
    positive_prop <- mean(response == "yes")
  }
  
  # Put these into the dataframe
  output_df <- output_df |>
               mutate(
                 omics_names = omics_names,
                 row_dimensions = row_dims,
                 col_dimensions = col_dims,
                 positive_prop = positive_prop,
                 is_simulated = is_simulated
               )
  return(output_df)
}

# This is the wrapper of main line codes
main <- function(mae_path_list, split=" ") {
  mae_path_list <- mae_path_list |> strsplit(split=split) |> unlist()
  # And initialize empty list to store results
  to_merge_list <- vector(mode="list", length=length(mae_path_list))
  for (i in seq_along(mae_path_list)) {
    mae_path <- mae_path_list[[i]]
    dataset_name <- gsub("_mae_data", "", x = basename(mae_path))
    # Load the mae from given path first
    mae <- loadHDF5MultiAssayExperiment(mae_path)
    # Run the helper above that parses metadata and store into df
    parsed_df <- parseMeta2df(mae=mae, dataset_name=dataset_name)
    # And append it to the empty list earlier
    to_merge_list[[i]] <- parsed_df
  }

  # Bind the list to single dataframe
  merged_df <- to_merge_list |> dplyr::bind_rows()

  # Lastly writing this to file
  output_file <- "parsed_metadata.csv"
  write.csv(merged_df, file=output_file, row.names=FALSE)
}

# And call the main fun
main(mae_path_list=opt$mae_path_list)

