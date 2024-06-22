# Data

This data directory contains several real multiomics dataset, mostly from real data, with some that are simulated using multivariate normal distribution.

Key files are those `samplesheet*.csv`, whereas they follow this format:

> [!NOTE]
> The entries of the csv are without '' or "" quotation marks, as nextflow could compain about this. If you would like to add a new data, follow similar format

```csv
dataset_name,tar_path
tcga-brca,/full_path_to_the_data/data/tcga-brca.tar.gz
tcga-kipan,/full_path_to_the_data/data/tcga-kipan.tar.gz
```

Then each of these `tar.gz` file is a compressed directory of dataset with both MultiAssayExperiment and MuData in it, with the following structure:

```
tcga-brca.tar.gz
  |
  |______tcga-brca/
  |      |________tcga-brca_mae_data/
  |      |        |_______ experiments.h5
  |      |        |_______ mae.rds 
  |      |________tcga-brca.h5mu
```
