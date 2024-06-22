# Now read in an MultiAssayExperiment and conver it to H5mu

library(MultiAssayExperiment)
library(here)
source(here("bin/savers/saveFile.R"))

dataset_name <- "tcga-thca"
s <- here("data/real_data/", dataset_name, paste0(dataset_name, "_mae_data"))
mae <- loadHDF5MultiAssayExperiment(s)

sample_names <- mae@ExperimentList[[1]] |> colnames()
mae@colData$sample_names <- sample_names
mae@metadata$sample_names <- sample_names


var_names <- lapply(mae@ExperimentList, rownames)

# NOw for MuData we need n x pi , so tranpose it back
object = list(blocks=mae@ExperimentList |> lapply(as.matrix) |> lapply(t), 
              metadata = mae@metadata)

save_mudata(object=object, name = dataset_name, message = "", var_names=var_names)

