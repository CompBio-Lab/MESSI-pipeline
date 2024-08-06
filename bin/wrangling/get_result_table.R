library(dplyr)
library(magrittr)
# Use this script to get result table
extract_fold_name <- function(label, pattern="fold_\\d+") {
  matches <- regmatches(label, gregexpr(pattern, label))
  return(unlist(matches))
}

get_result_table <- function(probs, label, method_name, test_data, digit=3) {
  # Label is usually dataset_name-fold_i
  # matching by sample names inside the data
  sample_name <-  rownames(test_data$X[[1]])
  # Use this pattern to remove unnessary info from label
  pattern <- "-fold.*"
  df <- tibble(sample_name = sample_name,
              y = test_data$Y) %>%
        full_join(probs,  by = "sample_name") %>%
        mutate_if(is.numeric, round, digit) %>%
        # add labels for grouping later
        mutate(
          method_name = method_name,
          dataset = gsub(pattern, "", label),
          # Add column to identify which fold was on
          fold = extract_fold_name(label)
          #dataset = sapply(strsplit(label, "-"), head, 1)
        )
  return(df)
}