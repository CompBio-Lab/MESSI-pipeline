#!/usr/bin/env Rscript
doc <- "
This script is used to load splits for indices in R

Author: Tony Liang

Usage:
  load_test_splits.R [options]
  
Options:
  --split_dir=SPLIT_DIR   Directory containing txt files of indices [default: empty]
  --name=NAME             Name of the unique identifier [default: empty]
"

# Parase docopt
opt <- docopt::docopt(doc)

load_test_splits <- function(split_dir, name, pattern=".txt", ...) {
  if (split_dir == "empty") {
    stop("You did not provide the directory that contains txt files of indices")
  }
  # Glob pattern
  idx_files <- list.files(path=here::here(split_dir), 
                          pattern=".txt", full.names = TRUE)
  # Read in data
  idx_list <- lapply(idx_files, function(f) {
    data <- scan(f, what = numeric(), quiet = TRUE)
    return(data)
  })
  
  # Check if it contains zero (hence assume it was 0index based)
  zero_indexed <- any(sapply(idx_list, function(vec) any(vec == 0)))
  # Then if true, shift all by 1
  if (zero_indexed) {
    cat("\nIndex founded to be 0 based, shift by 1 for all\n")
    idx_list <- lapply(idx_list, function(x) x + 1)
  }
  
  # Assign names based on loaded files
  idx_list <- setNames(idx_list, 
                       tools::file_path_sans_ext(basename(idx_files)))
  # Save to disk for rest
  if (name == "empty") {
    name <- "sample"
  }
  output_name <- paste0(name, "_test_splits.rds")
  cat("Saved to", output_name)
  saveRDS(idx_list, output_name)
}

# Execute it here
load_test_splits(split_dir = opt$split_dir, name=opt$name)