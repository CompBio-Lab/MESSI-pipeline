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
                  # Removes the prefix of the view from the feature 
                  mutate(
                    feature = purrr::map2_chr(
                      feature, view, ~ stringr::str_replace(.x, paste0(.y, "_"), "")
                    )
                  )
  # Writing to files both csv and txt for now
  file_name <- "all_feature_selection_results"
  csv_format <- paste0(file_name, ".csv")
  txt_format <- paste0(file_name, ".txt")
  # To disk
  write.csv(merged_table, csv_format, row.names = FALSE)
  return(merged_table)
}

# Call the main function here
print(opt)

main(tables=opt$tables)
