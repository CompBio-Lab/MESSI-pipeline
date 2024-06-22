# Script to load MAE data from disk
suppressPackageStartupMessages({
    library(MultiAssayExperiment)
})
# Read MAE from disk
load_MAE <- function(path, prefix="") {
  MAE <- tryCatch(
    expr = {
      loadHDF5MultiAssayExperiment(path, prefix=prefix)
    },
    error = function(e){ 
      message("\nLoad failed with prefix, skpping\n")
      message("\nError is:", e, "\n")
    }
  )
  return(MAE)
}
