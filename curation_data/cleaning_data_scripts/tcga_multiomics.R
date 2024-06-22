library(TCGAbiolinks)

tcga <- list("TCGA-BLCA" = list(comparison = c("stagei_ii", "stageiii_stageiv"),
                                stages = c("stagei"="stagei_stageii", "stageii"="stagei_stageii", 
                                           "stageiii"="stageiii_stageiv", "stageiv"="stageiii_stageiv"),
                      cancer_name = "bladder cancer",
                     link = "https://www.cancer.gov/types/bladder/stages",
                     datasets = c("Clinical", "Methylation (Gene level, HM450K)",
                                  "miRNA (Gene level)", "RPPA (Gene Level)",
                                  "RNAseq (HiSeq, Gene level)")),
     "TCGA-BRCA" = list(comparison = c("stagei_ii", "stageiii_stageiv"),
                        stages = c("stagei"="stagei_stageii", "stageii"="stagei_stageii", 
                                   "stageiii"="stageiii_stageiv", "stageiv"="stageiii_stageiv"),
                      cancer_name = "breast cancer",
                      link = "https://www.jbcp.jo/understandingbreastcancer/33",
                      datasets = c("Clinical", "Methylation (Gene level, HM450K)",
                        "miRNA (GA, Gene level)", "RPPA (Gene level)",
                        "RNAseq (HiSeq, Gene level)")),
     "TCGA-KIPAN" = list(comparison = c("stagei_ii", "stageiii_stageiv"),
                         stages = c("stagei"="stagei_stageii", "stageii"="stagei_stageii", 
                                    "stageiii"="stageiii_stageiv", "stageiv"="stageiii_stageiv"),
                          cancer_name = "kidney cancer",
                          link = "https://www.cancer.org/cancer/types/kidney-cancer/detection-diagnosis-staging/staging.html",
                         datasets = c("Clinical", "Methylation (Gene level, HM450K)",
                                       "miRNA (GA, miRgene level)", "RPPA (Gene Level)",
                                       "RNAseq (HiSeq, Gene level)")),
     "TCGA-THCA" = list(comparison = c("stagei_ii", "stageiii_stageiv"),
                        stages = c("stagei"="stagei_stageii", "stageii"="stagei_stageii", 
                                   "stageiii"="stageiii_stageiv", "stageiv"="stageiii_stageiv"),
                       cancer_name = "thyroid cancer",
                       link = "https://www.cancer.org/cancer/types/thyroid-cancer/detection-diagnosis-staging/staging.html",
                       datasets = c("Clinical", "Methylation (Gene level, HM450K)",
                                     "miRNA (Gene level)", "RPPA (Gene Level)",
                                     "RNAseq (HiSeq, Gene level)")))

all_data <- lapply(names(tcga), function(cancer){
  ## Download data
  dats <- lapply(tcga[[cancer]]$datasets, function(data){
    omics_data <- getLinkedOmicsData(
      project = cancer,
      dataset = data
    )
  })
  names(dats) <- datasets
  
  ## select common subjects and transpose data
  processed_data <- lapply(dats, function(i){
    x <- as.data.frame(i[, Reduce(intersect, sapply(dats, colnames))])
    xx <- x[,-1]
    rownames(xx) <- x$attrib_name
    t(xx)
  })
  ## add response
  response <- processed_data$Clinical[, "pathologic_stage"]
  names(response) <- rownames(processed_data$Clinical)
  table(response)
  ## process clinical data
  clin <- data.frame(age = processed_data$Clinical[, "years_to_birth"],
                     sex = as.numeric(factor(processed_data$Clinical[, "gender"], levels = c("female", "male")))-1)
  processed_data$Clinical <- clin

  ## keep selected stages only
  response <- response[as.character(response) %in% names(tcga[[cancer]]$stages)]
  for(stage in names(tcga[[cancer]]$stages)){
    response[response %in% stage] <- tcga[[cancer]]$stages[stage]
  }
  processed_data <- lapply(processed_data, function(i){
    i[names(response), ]
  })
  processed_data$Y <- response
  processed_data
})
names(all_data) <- names(tcga)
# Save this to file
# saveRDS(all_data, "all_data.rds")

# Load libraries
library(MultiAssayExperiment)
# all_data <- readRDS("all_data.rds")
dnames <- names(all_data)


clean_data <- lapply(dnames, function(cancer) {
  d <- all_data[[cancer]]
  # For each of this dataset of cancer, rename those names
  # Replace spaces with _ and remove either parenthesis and comma
  names(d) <- gsub(" ", "_", names(d))
  names(d) <- gsub("[(),]", "", names(d))
  #names(d) <- gsub(",", "-", names(d))
  return(d)
}) 

names(clean_data) <- dnames

# Then could lapply this
mae_list <- lapply(names(clean_data), function(dataset_name) {
  raw_data <- clean_data[[dataset_name]]
  col_data_df <- cbind(raw_data$Clinical, response = factor(raw_data$Y)) |>
    dplyr::mutate(response = factor(as.numeric(response) - 1))
  # Extract diff comp from the data
  # Data comes in n x p_i format, so transform it to the MAE preferred one
  experiments <- raw_data[!names(raw_data) %in% c("Clinical", "Y")] |> 
    lapply(t)
  # Then should construct MAE
  mae <- MultiAssayExperiment(experiments=experiments, 
                              metadata=col_data_df,
                              colData = col_data_df
  )
  # And save each MAE out
  saveHDF5MultiAssayExperiment(x=mae, dir=paste0(tolower(dataset_name), "_mae_data"), prefix="")
  return(mae)
})


names(mae_list) <- names(all_data)






