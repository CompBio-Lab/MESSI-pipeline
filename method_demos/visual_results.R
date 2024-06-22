# Import libs
library(dplyr)
library(magrittr)
library(ggplot2)
library(caret)
# Params
threshold = 0.5
rs <- c("cooperative_learning", "diablo")
# Result dir
py_result = "results/cross_validation/cv_python/merge_result_table/Python-result.csv"
r_result = "results/cross_validation/cv_r/merge_result_table/R-result.csv"
# Read in those data
py_df <- read.csv(py_result)
r_df <- read.csv(r_result)
# Merge together by rows
combine_df <- function(py_df, r_df) {
  df <- rbind(py_df, r_df) %>%
    mutate(phat = abs(phat)) %>%
    mutate(yhat = ifelse(phat >= threshold, 1, 0),
           lang = ifelse(method_name %in% rs, "R", "Python")) %>%
    mutate(y = as.factor(y),
           yhat = as.factor(yhat))
  return(df)
}

df <- combine_df(py_df, r_df)


compute_summary <- function(df) {
  out_df <- df %>%
    mutate(
      TP = ifelse(yhat == 1 & y == 1, 1, 0),
      TN = ifelse(yhat == 0 & y == 0, 1, 0),
      FP = ifelse(yhat == 1 & y == 0, 1, 0),
      FN = ifelse(yhat == 0 & y == 1, 1, 0)
    ) %>%
    group_by(dataset, method_name) %>%
    summarize(TN = sum(TN),
              TP = sum(TP),
              FN = sum(FN),
              FP = sum(FP)) %>%
    mutate(
      Sensitivity = TP / (TP + FN),
      Specificity = TN / (FP + TN),
      Precision = TP / (TP + FP), 
      Accuracy = (TP+TN) / (TP + FP +TN + FN),
      FPR = FP / (FP + TN),
      F1 = 2 *Precision * Sensitivity / (Precision + Sensitivity)
    ) %>%
    select(-TN, -TP, -FN, -FP)
}


# confusion matrix?

summary_df <- compute_summary(df)
colnames(summary_df)

kl <- summary_df %>%
  pivot_longer(cols = -c(dataset, method_name), names_to = "Metric") %>%
  ggplot(aes(x=method_name, y=value, fill=method_name)) +
  geom_boxplot() + 
  theme_bw() +
  theme(axis.title.x=element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.x=element_blank()) +
  facet_wrap(~Metric, scales = "free")

ggsave(filename = "boxplot.png", kl, dpi = 1200)
