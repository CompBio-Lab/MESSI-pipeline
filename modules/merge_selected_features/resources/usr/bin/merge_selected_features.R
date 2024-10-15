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

main <- function(tables, method_name, methodMode, readMode="csv", pattern="-result.*") {
  # Special script to handle here
  tables <- strsplit(tables, " ") |> unlist()
  # Store to list and bind by rows laters
  to_bind <- vector(mode="list", length=length(tables))
  for (i in seq_along(tables))  {
    table_path <- tables[i]
    # Then just read in the selecetd features of random method + dataset combination
    table <- read.csv(table_path, header=TRUE)
    # Add to our initial list
    to_bind[[i]] <- table
  }
  cat("\nMerging", length(to_bind), "tables\n")
  # Flatten these tables by merging rows
  merged_table <- dplyr::bind_rows(to_bind) %>%
                  mutate(
                    feature_type = ifelse(
                      # Make column to identify current feat is actual "true" var or "noise" var
                      stringr::str_detect(feature, "noise"),
                        "noise",
                        "true"
                      )
                  ) %>%
                  select(feature, feature_type, view, coef, method, dataset_name)
  # Then for counting those of relevant features
  method_view_dname_counts_df <- merged_table %>%
    group_by(method, dataset_name, view) %>%
    summarize(
      total_var_n = n(),
      true_var_n = sum(feature_type == "true"),
      noise_var_n = sum(feature_type == "noise")
    ) %>%
    ungroup()

  relevant_feats_df <- merged_table %>%
    group_by(method, view, dataset_name) %>%
    group_modify(
      ~ slice_max(.x, order_by = abs(.x$coef), n = sum(.x$feature_type == "true"))
    ) %>%
    group_by(method, view, dataset_name) %>%
    summarize(
      total_true = n(),
      true_selected = sum(feature_type == "true"),
      noise_selected = sum(feature_type == "noise")
    ) %>%
    ungroup() %>% 
    left_join(
      method_view_dname_counts_df, 
      by = c("method", "view", "dataset_name")
    ) %>%
    mutate(
      dataset_type = case_when(
        str_detect(dataset_name, "sim") ~ "simulated",
        TRUE ~ "real"
      )
    ) %>%
    filter(dataset_type == "simulated") %>%
    # Alter order
    select(method, view, dataset_name, dataset_type,
          total_true, true_var_n, true_selected, noise_selected,
          noise_var_n, total_var_n)
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
  to_csv(merged_table, filename=all_feats_file_name, row.names=FALSE)
  to_csv(relevant_feats_df, filename=relevant_feats_file_name, row.names=FALSE)
  # csv_format <- paste0(file_name, ".csv")
  # txt_format <- paste0(file_name, ".txt")
  # write.csv(merged_table, csv_format, row.names = FALSE)
  return(merged_table)
}

# Call the main function here
print(opt)

main(tables=opt$tables)
