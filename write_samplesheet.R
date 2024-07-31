aa <- list.files("/arc/project/st-singha53-1/datasets/messi_demo_data", pattern = "*.gz", full.names = T)
library(dplyr)
library(magrittr)
library(stringr)

library(MultiAssayExperiment)


# str_replace(tar_path, pattern = ".tar.gz", replacement = ""

#stringr::str_detect(samplesheet_df$dataset_name, pattern = "sim_data")

samplesheet_df <- aa |> 
  as.data.frame() |>
  rename(tar_path = aa) |>
  mutate(dataset_name = basename(tar_path) |> str_replace(pattern = ".tar.gz", ""),
         is_simulated = ifelse( str_detect(dataset_name, "sim_data"), 1, 0)
         ) %>%
  select(dataset_name, tar_path) 

samplesheet_df

samplesheet_df %>%
  write.csv(file="samplesheet_with_sim.csv", quote=F, row.names = F)
