#!/usr/bin/env Rscript
doc <- "
This script is used to merge feature selected result tables from specific method and dataset

Author: Tony Liang

Usage:
  merge_selected_features.R [options]
  
Options:
  --tables=TABLES    Joined path of list of the result table of particular fold or dataset of method [default: empty]
"

# Parase docopt
opt <- docopt::docopt(doc)

library(magrittr)
library(dplyr)
library(stringr)


# Small little helper to write csv
to_csv <- function(df, filename="", row.names=FALSE) {
  out_name <- paste0(filename, ".", "csv")
  df %>%
  write.csv(file=out_name, row.names=row.names)
}

combine_csvs <- function(tables, mode=c("data.table", "baseR")) {
  mode <- match.arg(mode)
  cat("\nCombine csvs using ", mode, " approach\n")
  
  if (mode == "baseR") {
    to_bind <- vector(mode="list", length=length(tables))
    for (i in seq_along(tables))  {
      table_path <- tables[i]
      # Then just read in the selecetd features of random method + dataset combination
      table <- read.csv(table_path, header=TRUE)
      # Add to our initial list
      to_bind[[i]] <- table
    }
    dplyr::bind_rows(to_bind)
  }
  
  if (mode == "data.table") {
    data.table::rbindlist(
      lapply(tables, data.table::fread)
      )
  }
}

get_relevant_feats_sim <- function(merged_table) {
  # Then to handle those of simulated data
  relevant_feats_df <- merged_table %>%
    filter(dataset_type == "sim") %>%
    group_by(method, dataset_name, view) %>%
    # Positive being true predictor
    # Negative being simulated predictor
    mutate(
      total_positive_n = sum(feature_type == "real"),
      total_n = n(),
      total_negative_n = sum(feature_type == "noise")
      ) %>%
    arrange(desc(abs(coef))) %>%
    group_map(~ {
      # Extract the group keys and the data
      group_keys <- .y
      sliced_data <- slice_head(.x, n = unique(.x$total_positive_n))
      
      # Add the group keys back to the sliced data
      bind_cols(group_keys, sliced_data)
    }) %>%
    # Combine the results back into a dataframe 
    bind_rows() %>%
    # These are final columns to collect, along with those in summarize
    group_by(method, dataset_name, view, total_positive_n, total_n, total_negative_n) %>%
    summarize (
      predicted_positive_n = sum(feature_type == "real"),
      predicted_negative_n = sum(feature_type == "noise")
    ) %>%
    ungroup()

    return(relevant_feats_df)
}  




main <- function(tables, method_name, methodMode, readMode="csv", pattern="-result.*") {
  # Special script to handle here
  tables <- strsplit(tables, " ") |> unlist()
  contains_sim <- any(grepl("sim", tables))

  cat("\nMerging", length(tables), "tables\n")

  merged_table <- combine_csvs(tables, mode="data.table")

  # Flatten these tables by merging rows
  output_table <- merged_table %>%
                  mutate(
                    feature_type = ifelse(
                      # Make column to identify current feat is actual "true" var or "noise" var
                      str_detect(feature, "noise"),
                      "noise",
                      "real"
                    ),
                    dataset_type = ifelse(
                      str_detect(dataset_name, "sim"),
                      "sim",
                      "real"
                    )
                  ) %>%
                  # Make this order of columns available
                  select(
                    feature, feature_type, view, coef, 
                    method, dataset_name, dataset_type
                  )


  if (contains_sim) {
      relevant_feats_df <- get_relevant_feats_sim(output_table)
      relevant_feats_file_name  <- "relevant_feature_selection_results"
  }
  
  
    # Stale code, since this might cause problem
    # Removes the prefix of the view from the feature 
    # TODO: this could be dangerous?
    # This only replaces if contains _ :
    #  - feat = abc , nothing will be done
    #  - feat = aaa_bbb , aaa would be feat, bbb would be view
    #  BUT the last one could be misleading
    # mutate(
    #   feature = purrr::map2_chr(
    #     feature, view, ~ stringr::str_replace(.x, paste0(.y, "_"), "")
    #   )
    # )
  # Writing to files both csv and txt for now
  all_feats_file_name       <- "all_feature_selection_results"
  relevant_feats_file_name  <- "relevant_feature_selection_results" 

  # To disk
  # Filename doesnt need the extension, auto turned into csv
  to_csv(output_table, filename=all_feats_file_name, row.names=FALSE)
  if (contains_sim) {
    to_csv(relevant_feats_df, filename=relevant_feats_file_name, row.names=FALSE)
  }

  # csv_format <- paste0(file_name, ".csv")
  # txt_format <- paste0(file_name, ".txt")
  # write.csv(merged_table, csv_format, row.names = FALSE)
  return(output_table)
}

# Call the main function here
print(opt)

main(tables=opt$tables)
