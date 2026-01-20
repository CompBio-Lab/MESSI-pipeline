# MESSI: Multimodal Experiments with SyStematic Interrogation


A Nextflow pipeline for benchmarking multimodal (genomics, proteomics, metabolomics, imaging, clinical) data integration methods with systematic evaluation for classification tasks.


![](assets/MESSI_workflow_overview_diagram.png)

---

## Table of contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Project Structure](#project-structure)
4. [Installation & Setup](#installation-and-setup)
   - [Local Machine Setup](#local-machine-setup)
   - [HPC Setup (UBC ARC Sockeye)](#hpc-setup-ubc-arc-sockeye)
5. [Data Preparation](#data-preparation)
6. [Running the Pipeline](#running-the-pipeline)
   - [Local Execution](#local-execution)
   - [HPC Interactive Node](#hpc-interactive-node)
   - [HPC Batch Submission](#hpc-batch-submission)
7. [Configuration](#configuration)
8. [Result Inspection](#result-inspection)
9. [Troubleshooting](#troubleshooting)
10. [References](#references)
---

## Overview

The **MESSI Pipeline** provides a standardized benchmarking framework for multimodal data integration methods implemented in R and Python. It supports:

- **Multiple computational backends**: Local machines, HPC interactive sessions, HPC batch jobs, and job arrays

- **Containerized environments**: Docker (local) and Apptainer/Singularity (HPC)

- **Reproducible workflows**: Nextflow-based execution with comprehensive logging

- **Flexible data formats**: MultiAssayExperiment (R) and MuData (Python)

## Prerequisites

### Minimum System Requirements

| Software | Version | Purpose |
|:-:|:-:|:-:|
| Nextflow | $\geq$ 22.10.7 | Workflow orchestration |
| Java (OpenJDK) | 11-18 | Nextflow runtime |
| Bash | $\geq$ 4.2.46 | Shell scripting |
| Git | $\geq$ 2.31.8 | Version control |
| Make | $\geq$ 3.82 | Build automation (**Optional**) |


### Container Runtime (choose one)

- **Local**: Docker $\geq$ 0.10.23, build 715524
- **HPC**: Apptainer $\geq$ 1.1.4

### System Resources (Recommended)

- **Local**: 16GB RAM, 4+ CPU cores, 16GB storage

- **HPC**: Varies by dataset (configured in profiles at `conf/*.config`)





## Project Structure

```bash
MESSI-pipeline/
├── LICENSE
├── Makefile # Automated setup commands
├── README.md
├── bin/ # Setup and Utility scripts
├── conf/
│   ├── base.config # Basic resource settings designed to be overridden
│   ├── local.config # Local machine profile
│   ├── sockeye.config # HPC profile for UBC ARC Sockeye
│   └── test.config # Minimal test profile (quick run)
├── containers/ # Container definitions and build scripts
│   ├── README.md
│   ├── dockerfiles # Source Dockerfiles for each method
│   └── scripts # Build scripts for containers
├── data/ # Samplesheets (input of pipeline) and test data (tar.gz)
│   ├── README.md
│   ├── rosmap.tar.gz # Example dataset
│   └── samplesheet_test_small.csv # Example samplesheet of 1 data only
├── docs/ # Documentation and tutorials
├── launch_MESSI_pipeline.sh # Wrapper script to launch the pipeline
├── launcher_sockeye.sh  # HPC batch submission script
├── main.nf # Main Nextflow pipeline script
├── modules/ # Method and utility source codes
├── nextflow.config # Nextflow configuration file (loads other conf files through profiles)
├── sample.env # Sample environment variable template to modify for HPC usage
├── subworkflows/ # Subworkflows for high-level pipeline structure
├── templates/ # Templates for method implementations
│   ├── cli_scripts
│   └── nxf_scripts
└── workflows # High-level workflow definitions
    └── messi_benchmark.nf # Main benchmarking workflow

```

## Installation and Setup


### Local Machine Setup

#### Install dependencies

Install Nextflow in unix-like system (Linux/macOS):

```bash
curl -s https://get.nextflow.io | bash
# If not have sudo, you could move it to a directory in your PATH variable of shell
sudo mv nextflow /usr/local/bin/
```

Install Docker from [here](https://docs.docker.com/get-docker/).

---

Install [other dependencies](#minimum-system-requirements) using your system's package manager.


Example installation commands for macOS:

**macOS (Homebrew)**:
```bash
brew install openjdk@11 make git
# Ensure Docker Desktop is installed and running
```

Example installation commands for Ubuntu/Debian:

**Linux (Ubuntu/Debian)**:
```bash
# Install Java
sudo apt update
sudo apt install openjdk-11-jdk make git
```

#### Verify installations

```bash
# Test Nextflow
nextflow info
# Test docker 
docker --version
```

> [!NOTE]
> If `nextflow info` returns error, then likely Java is not properly installed or configured as it relies heavily on Java runtime.
>
> Also, docker images will be pulled during the pipeline execution, ensure Docker Desktop is running before executing the pipeline.


### HPC Setup (UBC ARC Sockeye)

#### Login and Load modules

```bash
# SSH into Sockeye
# replace cwl with your actual username
ssh cwl@sockeye.arc.ubc.ca

# Navigate to scratch space (IMPORTANT: not home directory)
cd /scratch/<ALLOCATION_CODE>/<USER>/

# Clean module environment
module purge

# Load required modules
module load gcc/9.4.0 git/2.31.8 apptainer/1.3.1
```


#### Clone the repository in login node

```bash
# Important: this must be done in the login node, otherwise you wiil not have internet access during computation nodes
git clone git@github.com:CompBio-Lab/MESSI-pipeline.git
```


#### Configure environment variables

```bash
# Copy the sample env file to .env to modify
cp sample.env .env
nano .env
```

When editing the `.env` file, replace the following variables accordingly:

```bash
ALLOCATION_CODE=REPLACE # This should be the account to deduct computing resources usage
MAIL_USER=REPLACE # This should be the email to receive notification of the pipeline
# This needs to be set for future use in the pipeline
APPTAINER_IMAGE_CACHE_DIR=/arc/project/${ALLOCATION_CODE}/${USER}/MESSI-apptainer-images
```

> [!Warning]
> Make sure you do NOT track this .env file onto git


#### Pull Apptainer images

```bash
# ALLOCATION_CODE should be non null/empty from the .env file you have set above if done correctly
# USER is native from ARC (everyone's cwl)
# Load the configured environment variables
source .env
mkdir -p ${APPTAINER_IMAGE_CACHE_DIR}
# Run this command under the this same pipeline root dir ~/scratch/<ALLOCATION_CODE>/<USER>/MESSI-pipeline
# Trigger the setup to pull apptainer images into above ${APPTAINER_IMAGE_CACHE_DIR}
make setup
```

> [!NOTE]
> This should be run on login node only as it requires internet, otherwise would fail at compute node. This step could take a while depending on your internet speed, better to run it in a `tmux` or `screen` session to avoid disconnection. 


**Troubleshooting "no space left" errors**:
```bash
# Clear Apptainer cache in your user home directory
cd ~
rm -rf .apptainer/cache # DANGER: recursive delete, be careful with wrong path
```

#### Verify Apptainer images

```bash
# Load the configured environment variables
source .env
# Check images directory
ls /arc/project/${ALLOCATION_CODE}/${USER}/MESSI-apptainer-images

# Expected contents:
# codia.sif
# cooperative_learning.sif
# mae_mudata.sif
# mixdiablo.sif
# mofa.sif
# mogonet.sif
# rgcca.sif
# save_simulate.sif
```

## Create your samplesheet

The pipeline expects a samplesheet in CSV format specifying dataset names and paths. A sample is provided at `data/samplesheet_test_small.csv`. The paths should be absolute paths to the `tar.gz` files containing your datasets.


**Local samplesheet example**:

Create a samplesheet for local testing named `data/local_samplesheet.csv`:
```csv
dataset_name,tar_path
rosmap,/local_absolute_path/MESSI_pipeline/data/rosmap.tar.gz
```

**HPC samplesheet example**:

Use any of provided samples at `data/samplesheet_test_small.csv` or `data/samplesheet_test_full.csv`. The first one is for quick run of 1 dataset, while the latter contains multiple datasets for full benchmarking.


## Running the Pipeline

### Local Execution

For testing and small runs on local machine with Docker. This is useful for development and debugging.

Currently works on linux **amd64** systems with Docker installed. Future support for **arm64** planned.

#### Basic Run

Run the pipeline with the following command using data from [`data/local_samplesheet.csv`](#create-your-samplesheet):

```bash
nextflow run main.nf \
      -c nextflow.config \
      -profile standard,docker,test  \
      --samplesheet data/local_samplesheet.csv \
      --outdir results \
      --pipeline_dir ./
```

This runs the pipeline with the `standard`, `docker`, and `test` profiles for local execution using Docker containers and a small test dataset. Outputs are saved to the `results/` directory.  

You could supply other parameters as needed via `--<param_name> <value>`, or edit that `<param_name>` in the `nextflow.config` file directly. 

**NOTES**: 

- No space in the profile part has to be this: `profile1,profile2`, not this: `profile1, profile2`
- Ensure Docker Desktop is running before executing the pipeline.
- Pipeline options are supplied with two dash `--` , while Nextflow options use single dash `-`


#### Advanced Options

```bash
# Specify number of CPUs and memory
nextflow run main.nf \
  -profile standard,docker,test  \
  --samplesheet data/local_samplesheet.csv \
  --outdir results \
  --pipeline_dir ./
  --max_cpus 8 \
  --max_memory 32.GB

# Enable resume (skip completed tasks)
nextflow run main.nf \
  -profile standard,docker,test  \
  --samplesheet data/local_samplesheet.csv \
  --outdir results \
  --pipeline_dir ./
  -resume
```

The cli args have higher priority than config file settings. For example, `--max_cpus` here would override the cpu settings in the config files. For detailed explanation of order of precedence, refer to the [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html). For more details on available parameters, refer to the [Configuration](#configuration) section.






### HPC Interactive Node

For development, testing, and medium-sized datasets on HPC. Serves as a middle ground between local and batch execution. Not suitable for large-scale benchmarking due to resource constraints (mainly time limits). Better for quickly iterating on the pipeline before launching full batch jobs.

#### Request Interactive Session

Running the following command in the login node would request an interactive session:

```bash
# Load configured environment variables
source .env
# Request cpu interactive node (3 hours, 4 CPUs, 6GB RAM, no GPU)
# Again ALLOCATION_CODE should be non null/empty from the .env file you have set above if done correctly
salloc --time=3:00:00 --ntasks=4 --mem=6G --nodes=1 --account=${ALLOCATION_CODE}
```

Once inside the interactive node after SLURM allocates resources, your hostname should change to something like `se123` , where `123` is the node number assigned to you.

#### Load modules in interactive node

Clean the module environment to avoid conflicts and load compute canada modules (This command should be run first after entering the interactive node):

```bash
module purge
module load CVMFS_CC
```

Then, load relevant modules to start nextflow:

```bash
module load apptainer/1.3.4
module load java/17.0.6
module load nextflow/24.04.4
```

Verify nextflow loads correctly:

```bash
# NOTE: this NXF_HOME has to be set, and need to be writeable dir
# Otherwise, you would get an error of 'Unable to initialize nextflow environment'
export NXF_HOME=$(eval pwd) # Set it as current working directory
which nextflow
nextflow info
```

#### Run the pipeline in HPC interactive node

Loads previous configured environment variables from `.env` file:

```bash
# Source the .env file to load env variables
source .env
```

Need to specify an extra variable at runtime to tell nextflow to skip auto-update check as Sockeye has no internet access on compute nodes:

```bash
export NXF_OFFLINE='true'
```

Run the pipeline with the following command using data from `data/samplesheet_test_small.csv`:

```bash
# Run with HPC-local profile
# Uses local executor (no batch submission) but with HPC resource settings
# The profile built-in with apptainer
nextflow run main.nf \
  -c nextflow.config \
  -profile arc_local,test  \
  --samplesheet data/samplesheet_test_small.csv \
  --outdir results_hpc_interactive \
  --pipeline_dir ./
```

The above command runs the pipeline with the `arc_local` and `test` profiles for interactive execution on Sockeye using Apptainer containers and a small test dataset. Outputs are saved to the `results_hpc_interactive/` directory. This setting should look similar to local execution but with HPC resource configurations.

#### Exit interactive node

```bash
# When finished
exit
```

This should prompt you from `se123` back to the login node hostname like `login1`.


### HPC Batch Submission

For large-scale benchmarking on HPC. Suitable for long-running jobs and multiple datasets. Utilizes SLURM for job scheduling and resource management.

> [!NOTE]
> This requires prior setup of environment variables and Apptainer images as described in the [HPC Setup](#hpc-setup-ubc-arc-sockeye) section. Should be properly tested using interactive node before submitting batch jobs to avoid wasting compute resources.

The key idea here is to create a SLURM batch script that requests resources and runs the Nextflow pipeline with appropriate parameters. The submitted batch job will execute the pipeline (serving as a head monitoring job) and spawns multiple single or array jobs as needed without further user intervention. Make sure the head job is submitted for a long enough time; if it expires, the remaining ongoing jobs will be terminated by the HPC system.

Here are two ways to run it as batch mode:

#### Method 1: Using Launcher Script (Recommended)

```bash
# Edit launch script parameters
# This script has nextflow call inside it with proper SLURM resource allocation
# Should be generic enough for other SLURM systems too with minor modifications
nano launch_MESSI_pipeline.sh
```

Key variables to configure inside `launch_MESSI_pipeline.sh`:
```bash
# Nextflow profile(s) - can chain multiple: sockeye,test
PROFILE=sockeye,real_data

# Output directory with timestamp
timestamp=$(date +"%Y%m%d_%H%M%S")
OUTDIR=${timestamp}-job${SLURM_JOB_ID}-MESSI_results

# Input samplesheet
SAMPLESHEET=data/samplesheet_test_full.csv
```

**Submit the job**:
```bash
# Submit to SLURM
# This is a wrapper for settings specific to Sockeye
# launch_MESSI_pipeline.sh internally
bash launcher_sockeye.sh

# Check job status
squeue -u $USER

# View job output log
cat MESSI-main-<job-id>.log | less
```

#### Method 2: Direct SLURM Submission

```bash
# Create custom SLURM script
# NOTE: when using this way, you need to manually set allocation code, as it would not read from .env file
cat > run_messi.sh <<'EOF'
#!/bin/bash
#SBATCH --job-name=MESSI
#SBATCH --account=st-yourpi-1
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=MESSI-%j.out
#SBATCH --error=MESSI-%j.err
#SBATCH --mail-type=ALL
#SBATCH --mail-user=your.email@ubc.ca

module purge
module load CVMFS_CC
module load apptainer/1.3.4
module load java/17.0.6
module load nextflow/24.04.4

cd /scratch/${ALLOCATION_CODE}/${USER}/MESSI-pipeline

PIPELINE_DIR=$(eval pwd)
# AS per nextflow expert, work/ CANNOT be under /tmp
# NOTE: this NXF_HOME variable has to be in a writeable directory
export NXF_WORK="${PIPELINE_DIR}/work"
export NXF_HOME="${PIPELINE_DIR}"
export NXF_OFFLINE='true'

nextflow run main.nf \
  -profile sockeye \
  --samplesheet data/samplesheet_test_full.csv \
  --outdir results_${SLURM_JOB_ID} \
  -ansi-log false \
  -resume
EOF

# Submit as a batch job
sbatch run_messi.sh
```

### Data Source

Given ARC Sockeye have no internet connection on compute nodes, which means user cannot pull data during the pipeline computation. Hence, the data have to be previously stored in a common directory.



## Data Preparation

### Creating a Samplesheet

The samplesheet is a CSV file that tells MESSI which datasets to process and where to find them. This is the **main input** to the pipeline.

#### Samplesheet Format

A samplesheet is a simple CSV with two required columns:

| Column | Description | Example |
|--------|-------------|---------|
| `dataset_name` | Unique identifier for dataset | `my_dataset` |
| `tar_path` | Absolute path to `.tar.gz` file | `/path/to/my_dataset.tar.gz` |

#### Important Samplesheet Rules

| Rule | Wrong | Correct |
|------|---------|-----------|
| **No quotes** | `"dataset","path"` | `dataset,path` |
| **Absolute paths** | `datasets/data.tar.gz` | `/full/path/datasets/data.tar.gz` |
| **Exact column names** | `name,file_path` | `dataset_name,tar_path` |
| **No spaces in names** | `my dataset` | `my_dataset` |
| **Unix line endings** | Windows CRLF | Unix LF |
| **No trailing commas** | `dataset,path,` | `dataset,path` |

#### Common Samplesheet Errors

**Error 1: Quoted fields**
```csv
# Wrong
"dataset_name","tar_path"
"my_data","/path/to/data.tar.gz"

# Correct
dataset_name,tar_path
my_data,/path/to/data.tar.gz
```

**Error 2: Relative paths**
```csv
# Wrong
dataset_name,tar_path
my_data,../datasets/my_data.tar.gz

# Correct
dataset_name,tar_path
my_data,/arc/project/st-yourpi-1/datasets/my_data.tar.gz
```

**Error 3: Windows line endings**
```bash
# Check line endings
file samplesheet.csv
# Output: "ASCII text, with CRLF line terminators" 
# Fix with dos2unix
dos2unix samplesheet.csv

# Or with sed
sed -i 's/\r$//' samplesheet.csv
```

#### Using Your Samplesheet

Once created, specify it when running the pipeline:

```bash
nextflow run main.nf \
  ... \
  --samplesheet /full/path/to/your_samplesheet.csv
```


### Data Input Format Requirements

MESSI requires data in two formats packaged as compressed archives (`.tar.gz`):

1. **MultiAssayExperiment (MAE)** - for R-based methods
2. **MuData** - for Python-based methods

### Directory Structure in Archive

```
dataset_name.tar.gz
└── dataset_name/
    ├── mae_data/
    │   ├── experiments.h5
    │   └── mae.rds
    └── dataset_name.h5mu
```
### Creating MESSI-Compatible Data

A dummy example of how to create these data formats from raw matrices and metadata in R and Python is provided below using helper functions.

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

## Configuration

### Pipeline CLI Parameters

```bash
# Via command line
nextflow run main.nf --param_name value
```

Common parameters:

| Parameter | Default | Description |
|:-:|:-:|:-:|
| `--samplesheet` | `data/samplesheet_test_small.csv` | Path to samplesheet |
| `--outdir` | `results` | Output directory |
| `--max_cpus` | 16 | Maximum CPUs per task |
| `--max_memory` | 64.GB | Maximum memory per task |
| `--selectFeature` | true | Runs feature selection (takes longer time to finish) |
| `k_fold_number` | 5 | Number of folds for cross-validation |
| `split_type` | "skf" | Data splitting strategy: "skf" (stratified k-fold) or "logo" (Leave One Group Out) by sample name |

For full list of available parameters, refer to [`nextflow.config`](./nextflow.config)

### Profile Configuration

Profiles are defined in `nextflow.config` and `configs/*.config`:

```bash
# Use single profile
nextflow run main.nf -profile standard

# Chain multiple profiles (no spaces!)
nextflow run main.nf -profile standard,test,gpu,your_custom_profile
```

You could create your own custom profile by adding a new config file in `conf/` and specifying it in the `-profile` argument. This allows you to set for specific parameters to record experiment runs.

Create `configs/my_custom_run1.config`:
```groovy
profiles {
    my_custom {
        params {
            max_cpus = 32
            max_memory = 128.GB
            n_folds = 10
        }
        
        process {
            executor = 'slurm'
            queue = 'gpu'
            
            withLabel: 'gpu' {
                clusterOptions = '--gpus=1'
            }
        }
    }
}
```

Include it as a profile in `nextflow.config`:
```groovy
profiles {
    standard {
        includeConfig 'configs/standard.config'
    }
    // Add in your custom profile
    my_custom_run1 {
        includeConfig 'configs/my_custom.config'
    }
}
```

When running the pipeline, specify your custom profile:

```bash
nextflow run main.nf -profile standard,my_custom_run1
```


## Result inspection

### Monitoring Pipeline Progress

#### Real-time Monitoring

```bash
# Tail main log (local execution)
cat .nextflow.log | less

# For HPC batch jobs
cat MESSI-main-<job-id>.log | less
```

## Troubleshooting

### Common Issues

#### 1. "No space left on device" (HPC)

**Problem**: Apptainer cache fills home directory

**Solution**:
```bash
# Clear cache
rm -rf ~/.apptainer/cache
```

#### 2. "Command not found: nextflow"

**Problem**: Nextflow not in PATH

**Solution**:
```bash
# Find nextflow
which nextflow

# Add to PATH
export PATH=$PATH:/path/to/nextflow
```

#### 3. Pipeline Fails on Specific Task

**Problem**: Individual method execution fails

**Solution**:
```bash
# Check work directory for failed task
cd work///
cat .command.log
cat .command.err
# Check .nextflow.log for overall errors
cat .nextflow.log | less

# Re-run with that specific task resumed
nextflow run main.nf -profile sockeye --samplesheet data/samplesheet.csv -resume
```

#### 4. Container Pull Fails

**Problem**: Network issues or authentication

**Solution**:
```bash
# For Apptainer/Singularity
apptainer pull docker://tonyliang19/mixdiablo:latest

# For Docker
docker pull tonyliang19/mixdiablo:latest

# Check container registry status
curl -I https://hub.docker.com/
```

#### 5. Out of Memory Errors

**Problem**: Task exceeds allocated memory

**Solution**:
```bash
# Increase memory in config
# Edit configs/sockeye.config
process {
    withName: 'PROBLEM_PROCESS' {
        memory = '128.GB'
    }
}

# Or pass via command line
nextflow run main.nf --max_memory 256.GB
```

#### 6. Samplesheet Format Errors

**Problem**: CSV parsing fails

**Solution**:
```bash
# Verify no quotes
cat data/samplesheet.csv | grep '"'

# Verify absolute paths
cat data/samplesheet.csv | grep -v '^/'

# Check line endings (should be Unix LF, not Windows CRLF)
file data/samplesheet.csv

# Convert if needed
dos2unix data/samplesheet.csv
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




