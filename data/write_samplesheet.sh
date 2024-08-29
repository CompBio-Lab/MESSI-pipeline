#!/bin/bash
output_file="samplesheet.csv"

# Write CSV header
echo "dataset_name,tar_path" > $output_file

# Find all .tar.gz files and process them
DATA_DIR="/arc/project/st-singha53-1/datasets/messi_demo_data"
for file in $DATA_DIR/*.tar.gz; do
  # Get the full path
  full_path=$(realpath "$file")

  # Get the dataset name (filename without extension)
  dataset_name=$(basename "$file" .tar.gz)

  # Write to CSV
  echo "$dataset_name,$full_path" >> $output_file
done
