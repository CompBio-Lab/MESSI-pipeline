#!/bin/bash

# Input CSV file and the number of rows per split
input_file="samplesheet_with_sim.csv"
#rows_per_split=10  # Change this to the number of rows per split
# Desired number of smaller files
default_splits=5  # Change this to the number of desired files
num_splits=${1:-$default_splits}
echo "num splits: ${num_splits}"
# Count total number of lines (excluding header)
total_lines=$(($(wc -l < "$input_file") - 1))

# Dynamically calculate rows_per_split
rows_per_split=$(( (total_lines + num_splits - 1) / num_splits ))

# Initialize the starting and ending indices for naming
start_index=1
end_index=$rows_per_split

# Initialize the file counter
file_counter=0

# Extract the header
header=$(head -n 1 "$input_file")

# Split CSV into smaller files
tail -n +2 "$input_file" | split -l $rows_per_split - "split_temp_"

# Process each split and add header and rename files
for file in split_temp_*; do
  # Calculate the correct end index based on file length
  num_rows_in_file=$(wc -l < "$file")
  end_index=$((start_index + num_rows_in_file - 1))
  
  # Create the new file name based on index range
  new_file="samplesheet_${start_index}-${end_index}.csv"
  
  # Add header and combine it with the split file
  echo "$header" | cat - "$file" > "$new_file"
  
  # Update start index for the next file
  start_index=$((end_index + 1))
  
  # Remove temporary split file
  rm "$file"

  file_counter=$((file_counter + 1))
done

# Output the total number of CSV files created
echo "Splitting completed. $file_counter CSV files were created of $rows_per_split files"

