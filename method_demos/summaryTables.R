# Check for one method
library(dplyr)
df <- read.csv("results/merge_result_table/diablo/diablo-result.csv") 


getGse <- function(dataset) {
  out <- df %>%
    filter({{dataset}} == dataset) %>%
    mutate(sample_name = stringr::str_sort(sample_name, numeric=TRUE),
           true_y = ifelse(true_y == "yes", 1, 0),
           phat = abs(phat)) 
  return(out)
}
gse1 <- getGse("GSE1")
gse2 <- getGse("GSE2")
gse123 <- getGse("GSE123")

cross.entropy <- function(gse) {
  y <- gse$true_y
  yhat <- gse$phat
  x <- 0
  for (i in 1:length(y)) {
    x <- x + (y[i] * log(yhat[i]))
  }
  return(-x)
}

cross.entropy(gse1)

cross.entropy(gse2)

cross.entropy(gse123)
