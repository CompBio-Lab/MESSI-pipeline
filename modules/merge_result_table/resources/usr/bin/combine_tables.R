#!/usr/bin/env Rscript
doc <- "
This script is used to merge result tables from specific method

Author: Tony Liang

Usage:
  combine_tables.R [options]
  
Options:
  --tables=TABLES         Joined path of list of the result table of particular fold or dataset of method [default: empty]
  --method_name=MNAME     Name of method run on   [default: empty]
  --methodMode            Collecting results for method specific [default: false]
"

# Parase docopt
opt <- docopt::docopt(doc)

# Helper to check format of table and transform it 
convert_table_format <- function(table) {
  # Make sure first col is sample name
  cols <- colnames(table)
  # First col is always sample_name
  match_first_col <- cols[1] == "sample_name"
  if (!match_first_col) {
    stop("First column is not sample_name, wrong naming or missed somewhere")
  }
  # TODO: Should at least contain sample name, phat, method_name, dataset
  # TODO: allow this extra column of fold
  relevant_cols <- c("sample_name", "y",  "phat", "method_name", "dataset", "fold")
  contains_relevant_cols <- cols %in% relevant_cols
  if(!all(contains_relevant_cols)) {
    warning("\nResult table might not contain all relevant columns\n")
    # TODO: Find a better way for this?
    table <- table[, relevant_cols]
  }
  
  # Also check if has right column types
  bv <- c(1, 0)
  is_binary_y <- all(is.element(table$y, bv))
  if (!is_binary_y) {
    message("\nConverting y to binary output\n")
    table$y <- ifelse(table$y == "yes", 1, 0)
  }
  return(table)
}

main <- function(tables, method_name, methodMode, readMode="csv", pattern="-result.*") {
  # Special script to handle here
  tables <- strsplit(tables, " ") |> unlist()
  # Store to list and bind by rows laters
  to_bind <- list()
  # Check which string to replace instead
  #if (methodMode) {
    #cat("\nCombining results of method specific, use different pattern for label and save")
    #pattern <- "-[^-]*$"
    #if (override=="yes") {
    #  readMode <- "csv"
    #} else {
    #  readMode <- "table"
    #}
  #}
  for (table_path in tables) {
    # TODO: need to make this label and identifier better
    # Get everything before last hypen - to retrieve unique label
    label <- gsub(pattern, "", table_path)
    message("\nThis is label:", label, "\n")
    #table <- switch(
    #            readMode,
    #            "table" = read.table(table_path, header=TRUE),
    #            "csv"   = read.csv(table_path, header=TRUE)
    #            )
    # Force sample name to be character, as it could come in numbers as well as id names
    table <- read.csv(table_path, header=TRUE, colClasses=c("sample_name"="character"))
    # Check the format of each table aligns before adding into list
    to_bind[[label]] <- convert_table_format(table) # Add it to list
  }
  message("\nMerging", length(to_bind), "tables\n")
  # Flatten these tables by merging rows
  merged_table <- dplyr::bind_rows(to_bind)
  # Writing to files both csv and txt for now
  file_name <- paste(method_name, "result", sep="-")
  csv_format <- paste0(file_name, ".csv")
  txt_format <- paste0(file_name, ".txt")
  # To disk
  write.csv(merged_table, csv_format, row.names = FALSE)
  write.table(merged_table, txt_format, row.names = FALSE)
  return(merged_table)
}

main(tables=opt$tables, method_name=opt$method_name, methodMode=opt$methodMode)
