coop_files <- "results/cross_validation/cv_r/cooperative_learning/merge_result_table/cooperative_learning-result.csv"
diab_files <- "results/cross_validation/cv_r/diablo/merge_result_table/diablo-result.csv"
# Read in and bind rows
# TODO: ....
coop <- read.csv(coop_files)
diab <- read.csv(diab_files)








check_table_format <- function(table) {
  # Make sure first col is sample name
  cols <- colnames(table)
  # First col is always sample_name
  match_first_col <- cols[1] == "sample_name"
  if (!match_first_col) {
    stop("First column is not sample_name, wrong naming or missed somewhere")
  }
  # Should at least contain sample name, phat, method_name, dataset
  relevant_cols <- c("sample_name", "y",  "phat", "method_name", "dataset")
  contains_relevant_cols <- cols %in% relevant_cols
  # Renaming those not containing right one
  if(!all(contains_relevant_cols)) {
    cat("\nRenaming columns to right order or right names\n")
    colnames(table) <- relevant_cols
  }
  
  # Also check if has right column types
  bv <- c(1, 0)
  is_binary_y <- all(is.element(table$y, bv))
  if (!is_binary_y) {
    cat("\nConverting y to binary output\n")
    table$y <- ifelse(table$y == "yes", 1, 0)
  }
  return(table)
}

d2 <- check_table_format(diab) 
c2 <- check_table_format(coop)

big <- bind_rows(d2, c2) %>%
  mutate(phat = abs(phat),
         yhat = round(phat, 0),
         y_true = y) %>%
  select(-phat, -y)

library(tidyr)
mt <- big %>%
  group_by(dataset, method_name, yhat, y_true) %>%
  summarize(count = n()) %>%
  mutate(
    TP = if_else(yhat == 1 & y_true == 1, count, 0),
    TN = if_else(yhat == 0 & y_true == 0, count, 0),
    FP = if_else(yhat == 1 & y_true == 0, count, 0),
    FN = if_else(yhat == 0 & y_true == 1, count, 0)
  ) %>%
  mutate(
    
  )


mt %>%
  ggplot(aes(x=FP, fill=method_name)) +
  geom_bar()

library(caret)




b2 <- big %>%
      group_by(method_name, dataset, y, yhat) %>%
      summarize(count = n()) %>%
      mutate(TP = sum(count[y == 1 & yhat == 1]),
             TN = sum(count[y == 0 & yhat == 0]),
             FP = sum(count[y == 0 & yhat == 1]),
             FN = sum(count[y == 1 & yhat == 0])
             )
b2
b2 %>%
  mutate(TPR = TP / (TP + FN),
            FPR = FP / (FP + TN),
            Accuracy = (TP+TN)/ (TP + FP +TN + FN)) %>%
  ggplot(aes(x=method_name, y = Accuracy, fill=method_name)) + 
  geom_boxplot()


b2 %>%
  ggplot(aes(x= dataset, y = TP, fill = method_name)) +
  geom_boxplot() +
  facet_grid(.~method_name)

