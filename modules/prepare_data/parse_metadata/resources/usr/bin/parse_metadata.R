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

parseMeta2df <- function(mae, dataset_name=NULL, sim_base_dname="sim-data") {
  if (is.null(dataset_name)) stop("Did not provide a dataset name for current mae data")
  # TODO: need a more robust code on parsing the metadata
  # Create the dataframe
  # Each row should be a dataset
  output_df <- data.frame(dataset_name = dataset_name)
  # Now get various information from the mae
  # MAE comes in a P x n format, P is number of features == rows
  # and n is number of subjects == col
  omics_names <- names(mae@ExperimentList) |> paste(collapse=",")
  feat_dims <- sapply(mae@ExperimentList, nrow) |> paste(collapse = ",")
  subject_dims <- sapply(mae@ExperimentList, ncol) |> paste(collapse = ",")
  # This is response variable
  #response <- mae@metadata$response
  response <- colData(mae) |> as.data.frame() |> pull(response)
  is_binary_chr_factor <- is.factor(response) && length(levels(response)) == 2
  if (!is_binary_chr_factor) {
    # TODO: this is for regression purpose response
    message("Should not come to this branch for parsing response to df")
  } else {
    # Then should count those of response
    positive_prop <- round(mean(response == "yes"), digits=3)
  }
  # Add in for those of simulated data
  # When the pattern of sim-data found in dataset indicates its simulated data
  is_simulated <- ifelse(stringr::str_detect(dataset_name, sim_base_dname), 1, 0)
  # ============================================================================
  # Put these into the dataframe
  output_df <- output_df |>
               mutate(
                 omics_names = omics_names,
                 feat_dimensions = feat_dims,
                 subject_dimensions = subject_dims,
                 positive_prop = positive_prop,
                 is_simulated  = is_simulated
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
    # Parse the dataset name from the current path input
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

