#!/usr/bin/env Rscript
doc <- "
This script is used to merge result tables from specific method

Author: Tony Liang

Usage:
  calculate_metrics.R [options]
  
Options:
  --result_path=RES_PATH    Path to the merged result table [default: empty]
  --threshold=THRESHOLD     Threshold to classify phat as of class [default: 0.5]
  --calculateALL            Option to calculate all metrics or not [default: false]
  --toLonger                Convert the metrics in longer format or not [default: false]
"

# Parase docopt
opt <- docopt::docopt(doc)
#source("wrangle_data.R")
# Import libs
library(dplyr)
library(magrittr)
library(ggplot2)


wrangle_data <- function(df, threshold) {
  # Params
  rs <- c("cooperative_learning", "diablo")
  # Execute here
  wrangled <- df %>%
    # Some method gives negative value upon phat (i.e. Diablo)
    mutate(phat = abs(phat)) %>%
    # Create the predicted yhat against this use set threshold
    # Also create label of language
    mutate(yhat = ifelse(phat >= threshold, 1, 0),
           lang = ifelse(method_name %in% rs, "R", "Python")
    ) %>%
    mutate(y = as.factor(y),
           yhat = as.factor(yhat)
    ) %>%
    rename(method = method_name)
  
  return(wrangled)
}


main <- function(result_path, threshold, calculateALL, toLonger) {
  # I dont know what these are for ? 
  current <- getwd()
  all_files <- list.files(current)
  print(all_files)
  # Maybe was just for debug purpose
  cat("\nRead data from", result_path, "\n")
  df <- read.csv(result_path) %>%
        wrangle_data(threshold = threshold) %>%
        # mutate(
        #   # TODO: wrong calculation here
        #   TP = as.numeric(yhat == 0 & y == 0),
        #   TN = as.numeric(yhat == 0 & y == 0),
        #   FP = as.numeric(yhat == 1 & y == 0),
        #   FN = as.numeric(yhat == 0 & y == 1)
        # ) %>%
        group_by(dataset, method) %>%
        summarize(
          TP = sum(y == 1 & yhat == 1),
          TN = sum(y == 0 & yhat == 0),
          FP = sum(y == 0 & yhat == 1),
          FN = sum(y == 1 & yhat == 0),
          .groups = 'drop'
        ) %>%
        mutate(
          Sensitivity = TP / (TP + FN),
          Specificity = TN / (FP + TN),
          Precision = TP / (TP + FP), 
          Accuracy = (TP+TN) / (TP + FP +TN + FN),
          FPR = FP / (FP + TN),
          F1 = 2 *Precision * Sensitivity / (Precision + Sensitivity)
        )
  # If calculate all stuff returns all metrics, otherwise only
  # Provide accuracy
  exclude_vars <- c("TN", "TP", "FN", "FP")
  #subset_vars <- c("dataset", "method", "Accuracy")
  if (calculateALL) {
    cat("\nReporting all metrics\n")
    longer_file <- "longer_metrics.csv"
    df <- df %>%
          select(-exclude_vars) %>%
          tidyr::pivot_longer(cols = -c(dataset, method), names_to = "metric")
    cat("\nSaving longer format of data (metrics in one col) to", longer_file, "\n")
    write.csv(x=df, file=longer_file, row.names=FALSE)
    return(df)
  } else {
    cat("\nOnly reporting accuracy\n")
    metric_file <- "metrics.csv"
    cat("\nSaving metrics to", metric_file, "\n")
    write.csv(x=df, file=metric_file, row.names=FALSE)
    return(df)
  }
}

# Execute it here
main(
  result_path=opt$result_path, 
  threshold=as.numeric(opt$threshold), 
  calculateALL=opt$calculateALL,
  toLonger=opt$toLonger
  )