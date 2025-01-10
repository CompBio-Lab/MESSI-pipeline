# Multiomics Experiments with SyStematic Interrogation (MESSI)

**Table of contents**:

1. [Overview](#overview)
2. [Project Structure](#project-structure)
3. [Setup the project](#setup)
4. [Running the pipeline](#running-the-pipeline)
5. [Preparing Data](#preparing-the-data)
5. [Result Inspection](#result-inspection)
5. [References](#reference)

## Overview

The **MESSI Pipeline** is a nextflow pipeline designed for benchmarking multiomics (genomics, proteomics, metabolomics) data integration methods. These methods are often implemented in R/Python, with the task of classification/regression, factor analysis, clustering and others.

## Project Structure

Some important locations:

- Shell scripts for setting up the project is located at `bin/`
- Main configuration for the pipeline is at `nextflow.config`. Other parameters, resources settings are found under `configs/`.
- Python and R source codes of methods are located in `modules/`
- Software environment definitions (containers) are under `containers/`
- `docs/` contain several demos and explanations of the pipeline usage and keynotes.
- High level abstraction of the flow of pipeline is found under `subworkflows/`. These often trigger codes under `modules/`
- Nextflow, R, and Python templates for method implementation could be found under `templates/`


## Setup

> [!NOTE]
> This pipeline have only tested under UBC ARC Sockeye's high performance cluster (SLURM), hence all instructions here might not apply to others.

The main software dependencies are the following:

**Requirements**:

- [Nextflow 22.10.7 or above](https://www.nextflow.io/)
- Bash `4.2.46`
- Java 11 (or later, up to 18), recommend using openJDK `11.0.18` 
- Docker/Apptainer `1.1.4` (formerly Singularity `3.8.5`)
- make `>= 3.82`
- git `>= 2.31.8`

Once you have these requirements setup, then you could clone the project with `git` in your desired place and
change the directory to the clone repo:

```bash
# This would unload the current modules that you are using (could be easily reverted)
module purge
# Then load relevant modules
module load gcc/9.4.0 git/2.31.8
# Choose a place you like to clone the repo, ideally the scratch space
git clone git@github.com:CompBio-Lab/MESSI-pipeline.git
# Then go into the directory of the repo
```

Then, create a `.env` file in the current directory and use the following template:

This is exactly what's inside `sample.env`, simply replace the file to `.env` using this command:

```bash
mv sample.env .env
```

Then edit the contents of the new `.env` file instead:

```bash
# You could also use vi or vim
nano .env
```

```bash
# ----------------------------------------------
# INSIDE THE .env file
# ----------------------------------------------
# The renamed file should not be tracked by git
# Important variables to replace the value
ALLOCATION_CODE=REPLACE # This should be the account to deduct computing resources usage
USER=REPLACE # This should be your cwl 
MAIL_USER=REPLACE # This should be the email to receive notification of the pipeline
```

For example the `.env` could be like the following:

```bash
# NOTICE there's no space between the `=` in VAR=VALUE 
ALLOCATION_CODE=st-myuser-123
USER=my_cwl_username
MAIL_USER=dummy_name@gmail.com
```

> [!Warning]
> Make sure you do not track this .env file onto git

Then, you could start to setup the required apptainer images (This could take a while to run, better to hang it in a `tmux`/`screen` session) for the pipeline by the following command:

```bash
# Run this command under the this same pipeline root dir
make setup
```
> [!TIP]
> If you see an error of `no space left`, this is due to the apptainer cache that it creates in your home dir, which you could clean it by the following command:
>
> `rm -r ~/.apptainer/cache`

Then, you could resume the setup command after have encountered and solved the `no space error`:

```bash
make setup
```

Once you see the log:
```bash
Finished setting up environment
```
This means all required images have successfully downlaoded and stored under `/arc/project/<ALLOCATION_CODE>/<USER>/MESSI-apptainer-images`, this could be verified if this directory contains the following:

```bash
# ./ is /arc/project/<ALLOCATION_CODE>/<USER>/MESSI-apptainer-images
./
├── codia.sif
├── cooperative_learning.sif
├── intersim.sif
├── mae_mudata.sif
├── mixdiablo.sif
├── mofa.sif
├── mogonet.sif
├── mowgli.sif
├── muon-py.sif
├── rgcca.sif
└── save_simulate.sif
```

### Data Source

Given ARC Sockeye have no internet connection on compute nodes, which means user cannot pull data during the pipeline computation. Hence, the data have to be previouly stored in a common directory.

## Running the pipeline

You could start the pipeline by submitting the wrapper script that sends the batch script to SLURM using default parameters:

```bash
# If you see any complains from this script, then is likely you did not setup properly
# NOTE: this only works on the UBC ARC Sockeye platform for now
bash launcher_sockeye.sh
```

Actual parameters of the pipeline are set under the `launch_MESSI_pipeline.sh` script, speficifically these variables:

```bash
# This tells nextflow to use pre-defined configuration found at conf/
# Could chain more profiles like prof1,prof2,... NOTE: no space between ,
PROFILE=sockeye
# This sets the output directory to store final outputs of the pipeline
# If not like this way of adding timestamp, you could simply set it to a simpler path
timestamp=$(date +"%Y%m%d_%H%M%S")
OUTDIR=${timestamp}-job${SLURM_JOB_ID}-MESSI_results
# This is MAIN input file of the pipeline, where it defines the path to find data, and its metadata idetifiers like dataset name
SAMPLESHEET=data/samplesheet_test_full.csv
```

The most important variable here is `SAMPLESHEET`, where this is the main input file of pipeline. It's simply a csv where it specifies name of dataset and path to locate it like:

```csv
dataset_name,tar_path
rosmap,/arc/project/st-singha53-1/datasets/messi_demo_data/rosmap.tar.gz
tcga-blca,/arc/project/st-singha53-1/datasets/messi_demo_data/tcga-blca.tar.gz
```

> [!NOTE]
> The csv content here MUST be UNQUOTED. `tar_path` MUST be absolute path leading to `tar.gz` of dataset
>

For a detailted instruction on how to setup and add your own samplesheet to explore method performance under different datasets, please see this [section](#preparing-the-data).


Other meaningful variable is `PROFILE`, this is more of a nextflow feature, where you could read over the [nextflow official doc](https://www.nextflow.io/docs/latest/config.html#config-profiles) and set your own set of profile to override these default one. Suggested to use this `sockeye` profile, and add another one just to set some of the hyperpameters of the pipeline.


### Preparing the data

To use different data to evaluate methods, you must store the raw data in `tar.gz` format, where it is just a compressed archive of multiple files. The content of the `tar.gz` would be a directory to store the `MultiAssayExperiment` and file to store the `MuData` formats of multiomics data. Then list these as a `csv`, where each row is a different dataset, columns being metadata identifier (still in progress) and path to the tar gz. 

Here is a sample csv input file:

```csv
dataset_name,tar_path
rosmap,/arc/project/st-singha53-1/datasets/messi_demo_data/rosmap.tar.gz
tcga-blca,/arc/project/st-singha53-1/datasets/messi_demo_data/tcga-blca.tar.gz
```


You could verify the content and file structure of these tar to match the described above using these commands:

```bash
# Looking at the rosmap data only
cd /arc/project/st-singha53-1/datasets/messi_demo_data/
tar -xzf rosmap.tar.gz
```

The uncompressed archive is a directory named `rosmap` with the following contents:

```bash
rosmap
├── mae_data
│   ├── experiments.h5
│   └── mae.rds
└── rosmap.h5mu
```

These MAE and MuData could be saved using these helpers files and instructions:


Saving it into MAE

```R
# mae related
save_mae <- function(object, dname=NULL, x_name=NULL, y_name=NULL, prefix="", output_dir,...) {
  blocks <- object[[x_name]]
  metadata <- object[[y_name]] # Metadata should be dataframe
  if (!is.data.frame(metadata) & is.atomic(metadata)) {
    metadata <- data.frame(response = metadata)
  }

  # Check if all matrices have the same number of rows (n)
  same_n <- all(sapply(blocks, nrow) == nrow(blocks[[1]]))
  # Check if its N x p then tranpose it to p x N
  match_dim <- nrow(metadata) == nrow(blocks[[1]])
  # ---------------------------------------------------------------------
  if (same_n & match_dim) {
    # Need to transpose it to p_i * n for MAE use
    blocks <- lapply(blocks, t)
  } else {
    cat("\nRight format, nothing done\n")
  }
  mae <- MultiAssayExperiment::MultiAssayExperiment(
    experiments = blocks,
    metadata    = metadata
  )
  # Note, the delayed matrix is affecting the subset of metadata
  # so manually add response here
  if (! ("response" %in% colnames(metadata))) {
    stop("Could not find 'response' column in metadata")
  }
  mae$response <- metadata$response
  # Save to HDF5 format
  outdir <- paste0(dname, "_", "mae_data")
  MultiAssayExperiment::saveHDF5MultiAssayExperiment(
    mae, dir=outdir,
    prefix=prefix,
    replace=TRUE)

  message("Saved to ", outdir)
}
```

Saving it into MuData

```python
from mudata import MuData
from anndata import AnnData
import numpy as np
import pandas as pd


def save_mudata(object, dname, x_name, y_name,**kwargs):
  # Get blocks and metadata and other useful params
  blocks = object.get(x_name)
  metadata = object.get(y_name)

  # This is passed from R
  var_names = kwargs['var_names']
  
  

  # Combine to mudata
  mu_dict = {}
  for b, mat in blocks.items():
    var = pd.DataFrame(var_names[b], columns=["feature"])
    ann = AnnData(X = mat, 
                  obs = metadata, 
                  var = var)
    # This is also passed from R
    ann.obs_names = kwargs['sample_name']
    ann.var_names = var_names[b]
    mu_dict[b] = ann  
  
  # store to mudata
  mdata = MuData(mu_dict)
  output_name = f"{dname}.h5mu"
  mdata.write(output_name)
  return mdata

```

Saving it into tar.gz, where it calls the `save_mae` and `save_mudata` first

```R
library(reticulate)
use_python("/usr/bin/python")

reticulate::source_python("save_mudata.py")
source("save_mae.R")


save_gz <- function(object, dname=NULL, x_name=NULL, y_name=NULL, prefix="", ...) {
  if (is.null(x_name)) {
    stop("Need to provide key name of list containing list of X matrices")
  }

  if (is.null(y_name)) {
    stop("Need to provide key name of list containing dataframe of metadata")
  }

  if (is.null(dname)) {
    stop("Did not provide unique dataset name")
  }

  # Var names being the column ones
  # Sample names being the row names
  X <- object[[x_name]]
  X_dim <- dim(X[[1]])

  y <- object[[y_name]]
  if (!is.data.frame(y)) stop("Y is not datafram")
  if (nrow(y) == X_dim[1] ) {
    # Found rows being samples here
    var_names <- lapply(X, colnames)
    sample_name <- X[[1]] |> rownames()
  } else if (nrow(y) == X_dim[2]) {
    # Found rows being variables here
    var_names <- lapply(X, rownames)
    sample_name <- X[[1]] |> colnames()
  }


  save_mudata(object = object, dname = dname, x_name = x_name, y_name = y_name,
              var_names = var_names, sample_name = sample_name)

  save_mae(object = object, dname = dname, x_name = x_name, y_name = y_name)

  # Then move this to unique folder
  dname_folder <- dir.create(dname)

  # Move the generated files or folders into the directory
  mudata_file <- paste0(dname, ".h5mu")
  mae_folder <- paste0(dname, "_mae_data")


  # Move the mudata file
  if (file.exists(mudata_file)) {
    file.rename(mudata_file, file.path(dname, mudata_file))
  }

  # Move the mae folder (if it exists)
  if (dir.exists(mae_folder)) {
    file.rename(mae_folder, file.path(dname, mae_folder))
  }

  # Compress the directory into a .tar.gz file
  gz_file <- paste0(dname, ".tar.gz")
  tar(gz_file, files = dname, compression = "gzip")

  # Clean up: Remove the uncompressed directory after archiving
  unlink(dname, recursive = TRUE)

  message("Saved and compressed dataset as ", gz_file)
}
```

These helpers required your original data to be in a list format in R, where it should contains these keys:

1. X, named list of matrices where at least one of either all of row dimensions match or all of col dimensions match
2. Y, dataframe of metadata containing the response variable and sample_names
3. label, dataset name

Example of using these helpers like:

```R
label <- "example_data"
X <- list(o1=o1, o2=o2, o3=o3) # where each o are matrix, say all rows match, where rows being number of patients
Y <- data.frame(response=response, sample_names = rownames(o1))
example_data <- list(X=X, Y=Y, label=label)
# Then could be saved with
save_gz(object=example_data, dname=example_data$label, x_name="X", y_name="Y")
```

Once this is done, you could then create a new samplesheet under `data/` of this project and specified it in the `launch_MESSI_pipeline.sh`:

1. Creating the samplesheet `data/my_data.csv`:

```csv
dataset_name,tar_path
example_data,/arc/project/singha53-1/messi_demo_data/example_data.tar.gz
```

2. Modify the `SAMPLESHEET` in `launch_MESSI_pipeline.sh`

```bash
OUTDIR=${timestamp}-job${SLURM_JOB_ID}-MESSI_results
# Could either comment out old one or just replace its value NO SPACE between =
#SAMPLESHEET=data/samplesheet_feat_selection.csv
SAMPLESHEET=data/my_data.csv
```

3. Lastly just run it

```bash
bash launcher_sockeye.sh
```

## Result inspection

For viewing the log of current runtime status of the pipeline, you could check the latest `MESSI-main-<job-id>.log` file in the root dir of the repo:

```bash
# <job id> is the one generated from SLURM
# Usually numeric, for example 1234567 is a job id here:
cat MESSI-main-1234567.log
```

In order to see the results of the pipeline, you could inspect the final results in this directory as it progresses using this command:

```bash
# Assuming you are in the root dir of the repo
ls MESSI_results
```

The directory structure of the `MESSI_results/` should be like the following once the pipeline have completed:

```bash
MESSI_results
```


There's option to change this default directory by changing the `OUTDIR` param in the `launch_MESSI_pipeline.sh` script:

```bash
# It is possible to use a for loop in the bash script to pass multiple OUTDIR and run as a monte carlo cross validation
OUTDIR=another_directory_that_you_like
```


## License

This project is licensed under the [MIT License](LICENSE)

## Reference

Bredikhin, Danila, Ilia Kats, and Oliver Stegle. 2022. “MUON: Multimodal Omics Analysis Framework.” Genome Biology 23 (1): 42.

Di Tommaso, Paolo, Maria Chatzou, Evan W Floden, Pablo Prieto Barja, Emilio Palumbo, and Cedric Notredame. 2017. “Nextflow Enables Reproducible Computational Workflows.” Nature Biotechnology 35 (4): 316–19.

Ding, Daisy Yi, Shuangning Li, Balasubramanian Narasimhan, and Robert Tibshirani. 2022. “Cooperative Learning for Multiview Analysis.” Proceedings of the National Academy of Sciences 119 (38): e2202113119.

Jeong, Dabin, Bonil Koo, Minsik Oh, Tae-Bum Kim, and Sun Kim. 2023. “GOAT: Gene-Level Biomarker Discovery from Multi-Omics Data Using Graph ATtention Neural Network for Eosinophilic Asthma Subtype.” Bioinformatics, btad582.

Kurtzer, Gregory M, Vanessa Sochat, and Michael W Bauer. 2017. “Singularity: Scientific Containers for Mobility of Compute.” PloS One 12 (5): e0177459.

Singh, Amrit, Casey P Shannon, Benoı̂t Gautier, Florian Rohart, Michaël Vacher, Scott J Tebbutt, and Kim-Anh Lê Cao. 2019. “DIABLO: An Integrative Approach for Identifying Key Molecular Drivers from Multi-Omics Assays.” Bioinformatics 35 (17): 3055–62.

UBC Advanced Research Computing. 2019. “UBC ARC Sockeye.” UBC Advanced Research Computing. https://doi.org/10.14288/SOCKEYE.

Wang, T., Shao, W., Huang, Z. et al. MOGONET integrates multi-omics data using graph convolutional networks allowing patient classification and biomarker identification. Nat Commun 12, 3445 (2021). 




