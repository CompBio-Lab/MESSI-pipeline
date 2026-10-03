#!/usr/bin/env Rscript
doc <- "
This script is used to merge result tables from specific method

Author: Tony Liang

Usage:
  combine_tables.R [options]

Options:
  --input_list=FILE       Text file containing one input path per line
  --method_name=MNAME     Name of method run on   [default: empty]
  --methodMode            Collecting results for method specific [default: false]
  --outcome_type=OUTCOME  Outcome type to merge results from. One of 'classification' or 'survival'. [default: classification]
"

# Parse docopt
opt <- docopt::docopt(doc)



# ======================================================================

# Check required columns and return them in a consistent order
select_relevant_cols <- function(table, relevant_cols) {
  missing_cols <- setdiff(relevant_cols, colnames(table))

  if (length(missing_cols) > 0L) {
    stop(
      "Result table is missing required columns: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  return(table[, relevant_cols, drop = FALSE])
}


clean_classification_table <- function(table) {
  relevant_cols <- c(
    "sample_name", "y", "phat",
    "method_name", "dataset", "fold"
  )

  table <- select_relevant_cols(table, relevant_cols)

  # Normalize labels before validating and converting
  y <- tolower(trimws(as.character(table$y)))
  valid_labels <- c("0", "1", "no", "yes")

  invalid <- is.na(y) | !(y %in% valid_labels)

  if (any(invalid)) {
    stop(
      "Invalid or missing values in y: ",
      paste(unique(y[invalid]), collapse = ", "),
      ". Expected 0/1 or yes/no.",
      call. = FALSE
    )
  }

  table$y <- as.integer(y %in% c("1", "yes"))

  return(table)
}


clean_survival_table <- function(table) {
  relevant_cols <- c(
    "sample_name", "lp",
    "surv_365", "surv_548", "surv_730",
    "surv_1095", "surv_1461", "surv_1826",
    "time", "status",
    "method_name", "dataset", "fold"
  )

  table <- select_relevant_cols(table, relevant_cols)

  return(table)
}

convert_table_format <- function(table, outcome_type) {
  # sample_name can be anywhere in the input;
  # the cleaning functions move it to the first column.
  if (outcome_type == "classification") {
    return(clean_classification_table(table))
  } else if (outcome_type == "survival") {
    return(clean_survival_table(table))
  } else {
    stop(
      "Unsupported outcome_type: ", outcome_type,
      ". Expected 'classification' or 'survival'.",
      call. = FALSE
    )
  }
}




main <- function(input_list, method_name, methodMode, outcome_type, readMode="csv", pattern="-result.*") {
  # Special script to handle here
  tables <- readLines(input_list, warn=FALSE)
  tables <- tables[nzchar(trimws(tables))]
#  tables <- strsplit(tables, " ") |> unlist()
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
  for (i in seq_along(tables)) {
    # TODO: need to make this label and identifier better
    # Get everything before last hypen - to retrieve unique label
    table_path <- tables[[i]]
    label <- gsub(pattern, "", table_path)
    message("\nThis is label: ", label, "\n")
    #table <- switch(
    #            readMode,
    #            "table" = read.table(table_path, header=TRUE),
    #            "csv"   = read.csv(table_path, header=TRUE)
    #            )
    # Force sample name to be character, as it could come in numbers as well as id names
    table <- read.csv(table_path, header=TRUE, colClasses=c("sample_name"="character"))
    # Check the format of each table aligns before adding into list
    to_bind[[i]] <- convert_table_format(table, outcome_type) # Add it to list
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

main(input_list=opt$input_list, method_name=opt$method_name, methodMode=opt$methodMode, outcome_type=opt$outcome_type)
