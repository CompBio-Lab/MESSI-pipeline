# Script to run Cooperative Learning (simulate now)
"This script is to run Cooperative Learning (Based on glmnet) with option to run
logistic regression. 

Usage: R_run_cooperative_learning.R --path=<data_path>  [--prefix=<prefix>]

Options:
  -p --path=<data_path> Path to read data
  --prefix=<prefix>     Prefix to read HDF5 [default: pre]
" -> doc

# Load libraries
library(multiview)
opt <- docopt::docopt(doc)
source(here::here("modules/R/helpers.R"))

# model func
main <- function(data_path, prefix, ext=".rds") {
  if (grepl(ext, data_path)) {
    dat <- readSimulated(data_path, binary=TRUE)
    X <- dat$X
    Y <- dat$Y
  } else {
    mae <- MultiAssayExperiment::loadHDF5MultiAssayExperiment(
          dir     =   data_path,
          prefix  =  paste0("mae_", prefix)
    )
    full_X <- MultiAssayExperiment::assays(mae) |> standardizeX()
    full_Y <- mae$response |> binaryY()
  }
  # CV of  model
  #multiview.control(mxitnr  = 100)	
  cv_mod <- cv.multiview(X, Y, 
                        family = binomial(),
                        type.measure="deviance",
                        rho=0.5, trace.it = FALSE)
  #print(paste0("The time it took was ", end, "s"))
  return(cv_mod)

}


#data_path <- here::here("data/mae_data/gse71669_complete/")
#prefix <- "complete"
# data_path = "train_data.rds"

set.seed(329)
# Call the function here
cv_mod <- main(data_path = opt[["--path"]], prefix = opt[["--prefix"]])
# Binomial deviance plot
png(filename="simulated_cv_deviance_plot.png")
plot(cv_mod)
dev.off()

# Trace of coefficients
png(filename="simulated_cv_cofficients_plot.png")
plot(cv_mod$multiview.fit)
dev.off()
