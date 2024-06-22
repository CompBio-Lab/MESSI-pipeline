# ---------------------------------------------
# You have csv of dataset_name and tar gz path
# --------------------------------------------

dnames <- c("brca", "kipan")
tar_paths <- c(here::here("data/real_data/tcga-brca.tar.gz"), 
               here::here("data/real_data/tcga-kipan.tar.gz")
               )
df <- data.frame(dataset_name = dnames, tar_paths = tar_paths)

df |> write.csv(
  file="samplesheet_test.csv", row.names = F)
tar_path <- df$tar_paths[1]

cat("Files to untar:\n", untar(tar_path, list=T))

?untar

library(mixOmics)
library(MultiAs)
library(MultiAssayExperiment)

mae <- loadHDF5MultiAssayExperiment("tcga-brca_mae_data/")

mae

X <- mae@ExperimentList@listData

view_names <- names(X)
X2 <- lapply(view_names, function(view){
  # Long means p_i x n
  long_X_i <- X[[view]]
  # Wide means n x p_i
  wide_X_i <- t(long_X_i)
  zero_var_metrics <- nearZeroVar(x = wide_X_i)
  irrev_feats <- zero_var_metrics$Metrics |> rownames()
  # Then reduce those out and transpose it back to p_i x n
  long_X_i  <- long_X_i[!rownames(long_X_i) %in% irrev_feats, ]
  return(long_X_i)
})

X2

abc <- nearZeroVar(x = mae@ExperimentList$miRNA_GA_Gene_level |> t())

mae@ExperimentList$miRNA_GA_Gene_level 

mae@ExperimentList$Methylation_Gene_level_HM450K

nos <- abc$Metrics |> rownames()
nos |> length()
se <- mae@ExperimentList$miRNA_GA_Gene_level


rownames(se)
se[!rownames(se) %in% nos, ] |> rownames()
