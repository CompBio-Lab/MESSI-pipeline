#!/usr/bin/env Rscript

doc <- "
This script is used to untar tar.gz files to get uncompressed folders,
whereas these are then used to read in MAE or MuData

Usage:
  uncompress_record.R [options]

Options:
  --dataset_name=DNAME  Name of the dataset [default: empty]
  --tar_path=TAR        Path to the tar.gz [default: empty]
"

opt <- docopt::docopt(doc)

main <- function(dataset_name, tar_path) {
  if (dataset_name == "empty" || tar_path == "empty") {
    stop("Did not provide the tar_path or dataset_name")
  }
  # Showing the files to untar
  cat("Files to untar:\n", untar(tar_path, list=T))

  # Then just untar it
  message("\nAbout to untar: ", tar_path, " correspoding to ", dataset_name)

  untar(tar_path)
}

# Call the main fun
main(dataset_name = opt$dataset_name, tar_path = opt$tar_path)
