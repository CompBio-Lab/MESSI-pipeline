# Guide: Adding a New Method to the MESSI Pipeline

**Author**: Tony Liang  
**Last Updated**: 2024-07-03

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start with Templates](#quick-start-with-templates)
4. [Step-by-Step Guide](#step-by-step-guide)
   - [Step 1: Create Dockerfile](#step-1-create-dockerfile)
   - [Step 2: Generate Method Template](#step-2-generate-method-template)
   - [Step 3: Implement Preprocessing](#step-3-implement-preprocessing)
   - [Step 4: Implement Training](#step-4-implement-training)
   - [Step 5: Implement Prediction/Testing](#step-5-implement-predictiontesting)
   - [Step 6: Implement Feature Selection (Optional)](#step-6-implement-feature-selection-optional)
   - [Step 7: Integrate into CV Workflow](#step-7-integrate-into-cv-workflow)
   - [Step 8: Build and Test](#step-8-build-and-test)
5. [Method Components Overview](#method-components-overview)
6. [Language-Specific Details](#language-specific-details)
7. [Troubleshooting](#troubleshooting)

---

## Overview

The MESSI pipeline uses Nextflow to orchestrate cross-validation of multiomics integration methods. Each method follows a standardized workflow:

```
Input Data → Preprocess → Train → Predict → Results
                              ↓
                    Feature Selection (optional)
```

**Key Concepts:**
- **R Methods**: Use `MultiAssayExperiment` (MAE) data format
- **Python Methods**: Use `MuData` format
- **Containerization**: Each method has its own Docker/Apptainer container
- **Workflows**: Methods are embedded in `CV_R` or `CV_PYTHON` workflows
- **Processes**: Each method has 4 processes: `preprocess`, `train`, `predict`, `select_feature`

---

## Prerequisites

Before adding a method, ensure you have:

1. **Method Implementation**: R or Python code for your multiomics integration method
2. **Dependencies**: List of software packages required by your method
3. **Docker**: For building container images
4. **Python**: For running the template generation script
5. **Repository Access**: Clone of the MESSI-pipeline repository

---

## Quick Start with Templates

The fastest way to add a method is using the template generation tool located in `bin/adding_method/`.

### Using the Template Generator

1. **Navigate to the project root:**
   ```bash
   cd /path/to/MESSI-pipeline
   ```

2. **Run the template generator:**
   ```bash
   python bin/adding_method/adding_method.py \
     --method=my_method \
     --language=R \
     --outdir=. \
     --docker_user=your_dockerhub_username
   ```

   **Parameters:**
   - `--method`: Name of your method (e.g., `logistic_reg`, `mofa`, `sklearn`)
   - `--language`: Either `R` or `Python`
   - `--outdir`: Output directory (use `.` for current/project root)
   - `--docker_user`: Your DockerHub username for container hosting
   - `--force_update`: Optional flag to overwrite existing method files

3. **What gets created:**
   - `subworkflows/methods/<method>/main.nf` - Main workflow
   - `modules/<method>/preprocess/main.nf` - Preprocessing process
   - `modules/<method>/train/main.nf` - Training process
   - `modules/<method>/predict/main.nf` - Prediction process
   - `modules/<method>/select_feature/main.nf` - Feature selection process
   - Binary scripts in `modules/<method>/*/resources/usr/bin/`
   - Automatic registration in `subworkflows/cross_validation/r/main.nf` or `python/main.nf`

---

## Step-by-Step Guide

### Step 1: Create Dockerfile

Your method needs a Docker container with all its dependencies.

#### For R Methods

Create `containers/dockerfiles/<method>.Dockerfile`:

```dockerfile
# Use the R method base template for common dependencies
FROM tonyliang19/r_method_base_dev

# The base image includes:
# - R (latest compatible version)
# - MultiAssayExperiment
# - here
# - docopt
# - HDF5Array

# Install method-specific packages
RUN Rscript -e "install.packages(c('package1', 'package2'))"

# Or install from Bioconductor
RUN Rscript -e "BiocManager::install(c('BiocPackage1', 'BiocPackage2'))"

# Or install from GitHub
RUN Rscript -e "devtools::install_github('user/repo')"
```

**Note**: If your method requires an older R version incompatible with the base template, you'll need to create a Dockerfile from scratch.

#### For Python Methods

Create `containers/dockerfiles/<method>.Dockerfile`:

```dockerfile
# Use Python base image
FROM python:3.9-slim

# Install system dependencies if needed
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip install --no-cache-dir \
    mudata \
    numpy \
    pandas \
    scikit-learn \
    docopt \
    # Add your method's dependencies here
    your-method-package

# Set working directory
WORKDIR /workspace
```

#### Build and Push Container

```bash
# Build the container
docker build -f containers/dockerfiles/<method>.Dockerfile \
  -t <dockerhub_user>/<method>:latest .

# Push to DockerHub
docker push <dockerhub_user>/<method>:latest

# For use on HPC (Apptainer/Singularity)
# Pull and convert on HPC:
apptainer pull <method>.sif docker://<dockerhub_user>/<method>:latest
```

---

### Step 2: Generate Method Template

Use the template generator as shown in [Quick Start](#quick-start-with-templates).

This creates all necessary Nextflow scripts and binary templates. Now you need to implement the actual logic.

---

### Step 3: Implement Preprocessing

**Purpose**: Split full dataset into train/test folds and prepare data format.

**File Location**: `modules/<method>/preprocess/resources/usr/bin/<method>_preprocess.{R,py}`

#### R Implementation Example

```r
#!/usr/bin/env Rscript

doc <- "Preprocess data for <method>

Usage:
  <method>_preprocess.R [options]

Options:
  --data_path=DATA_PATH     Path to MAE data
  --split_dir=SPLIT_DIR     Directory containing fold splits [default: splits]
  --dataset_name=NAME       Dataset name [default: empty]
"

opt <- docopt::docopt(doc)

library(MultiAssayExperiment)

# Helper: Load test splits from text files
load_test_splits <- function(split_dir) {
  idx_files <- list.files(split_dir, pattern=".txt", full.names = TRUE)
  idx_list <- lapply(idx_files, function(f) {
    data <- scan(f, what = numeric(), quiet = TRUE)
  })
  
  # Check if 0-indexed and shift if necessary
  zero_indexed <- any(sapply(idx_list, function(vec) any(vec == 0)))
  if (zero_indexed) {
    idx_list <- lapply(idx_list, function(x) x + 1)
  }
  
  names(idx_list) <- tools::file_path_sans_ext(basename(idx_files))
  return(idx_list)
}

# Helper: Reconstruct MAE after transformations
reconstruct_mae <- function(mae) {
  X <- mae@ExperimentList |> lapply(as.matrix)
  col_data <- colData(mae)
  MultiAssayExperiment::MultiAssayExperiment(experiments = X, colData = col_data)
}

# Main preprocessing function
main <- function(mae_path, split_dir, dataset_name) {
  cat("Processing:", dataset_name, "\n")
  
  # Load MAE
  mae <- loadHDF5MultiAssayExperiment(dir=mae_path, prefix="")
  
  # Load splits
  test_splits <- load_test_splits(split_dir)
  
  # Create fold directories
  for (fold_name in names(test_splits)) {
    split <- test_splits[[fold_name]]
    
    # Split into train/test
    # NOTE: MAE format is p_i x N (features x samples)
    # Apply transpose here if your method needs N x p_i
    tr_mae <- mae[, -split, drop=TRUE] |> reconstruct_mae()
    te_mae <- mae[, split, drop=TRUE] |> reconstruct_mae()
    
    # Create output directory structure
    dir.create(fold_name, showWarnings = FALSE)
    tr_path <- file.path(fold_name, paste0(fold_name, "_tr"))
    te_path <- file.path(fold_name, paste0(fold_name, "_te"))
    
    # Save MAEs
    saveHDF5MultiAssayExperiment(tr_mae, dir=tr_path, prefix="train")
    saveHDF5MultiAssayExperiment(te_mae, dir=te_path, prefix="test")
  }
}

# Execute
main(
  mae_path = opt[["--data_path"]],
  split_dir = opt[["--split_dir"]],
  dataset_name = opt[["--dataset_name"]]
)
```

#### Python Implementation Example

```python
#!/usr/bin/env python

"""Preprocess data for <method>

Usage:
  <method>_preprocess.py [options]

Options:
  --data_path=DATA_PATH     Path to MuData [default: empty]
  --split_dir=SPLIT_DIR     Path to splits [default: splits]
  --dataset_name=DNAME      Dataset name
"""

from docopt import docopt
import os
import glob
import numpy as np
import mudata

def load_test_splits(split_dir):
    """Load test indices from split directory"""
    files = glob.glob(os.path.join(split_dir, "*.txt"))
    split_dict = {}
    for i, file in enumerate(files):
        test_idxs = np.loadtxt(file).astype(int)
        split_dict[f"fold_{i+1}"] = test_idxs
    return split_dict

def main(mdata_path, split_dir, dataset_name):
    print(f"Processing: {dataset_name}")
    
    # Load MuData
    mdata = mudata.read(mdata_path)
    
    # Load splits
    splits = load_test_splits(split_dir)
    
    # Create fold directories
    for fold_name, test_idx in splits.items():
        # Get train indices
        all_idx = np.arange(mdata.n_obs)
        train_idx = np.setdiff1d(all_idx, test_idx)
        
        # Split data
        train_mu = mdata[train_idx].copy()
        test_mu = mdata[test_idx].copy()
        
        # Create output directory
        os.makedirs(fold_name, exist_ok=True)
        
        # Save
        train_mu.write(os.path.join(fold_name, f"{fold_name}_tr.h5mu"))
        test_mu.write(os.path.join(fold_name, f"{fold_name}_te.h5mu"))

if __name__ == "__main__":
    args = docopt(__doc__)
    main(
        mdata_path=args["--data_path"],
        split_dir=args["--split_dir"],
        dataset_name=args["--dataset_name"]
    )
```

**Important Notes:**
- Make script executable: `chmod +x <method>_preprocess.{R,py}`
- Must have shebang: `#!/usr/bin/env Rscript` or `#!/usr/bin/env python`
- Output structure must be: `fold_N/fold_N_tr/` and `fold_N/fold_N_te/`

---

### Step 4: Implement Training

**Purpose**: Train a model on the training portion of each fold.

**File Location**: `modules/<method>/train/resources/usr/bin/<method>_train.{R,py}`

#### R Implementation Example

```r
#!/usr/bin/env Rscript

doc <- "Train <method> model

Usage:
  <method>_train.R [options]

Options:
  --fold_path=FOLD_PATH     Path to fold directory
  --label=LABEL             Dataset-fold label [default: data]
  --prefix=PREFIX           HDF5 prefix [default: train]
  --method_name=METHOD_NAME Method name [default: <method>]
"

library(MultiAssayExperiment)
source("/workspace/bin/rhelpers.R")  # Helper functions from pipeline

opt <- docopt::docopt(doc)

main <- function(fold_path, label, prefix, method_name) {
  cat("Training fold:", fold_path, "\n")
  
  # Find train/test directories
  d <- list.files(fold_path, full.names = TRUE)
  train_path <- d[grepl("_tr", d)]
  test_path <- d[grepl("_te", d)]
  
  # Load MAE and extract X, y
  train_mae <- loadHDF5MultiAssayExperiment(train_path, prefix="train")
  test_mae <- loadHDF5MultiAssayExperiment(test_path, prefix="test")
  
  # Extract data (example assumes helper function extract_Xy exists)
  # This typically converts MAE to list with X (features) and y (response)
  train_data <- extract_Xy(train_mae)
  test_data <- extract_Xy(test_mae)
  
  # YOUR METHOD TRAINING LOGIC HERE
  # Example for logistic regression:
  # X_train <- do.call(cbind, train_data$X)  # Combine omics
  # y_train <- train_data$y
  # model <- glm(y_train ~ X_train, family = binomial())
  
  # Placeholder - replace with your method
  model <- list(
    method = method_name,
    # Add your trained model components
  )
  
  # Save outputs
  model_file <- paste(label, paste(method_name, "model.rds", sep="_"), sep="-")
  test_file <- paste(label, "test_data.rds", sep="-")
  
  saveRDS(model, model_file)
  saveRDS(test_data, test_file)
  
  cat("Training complete\n")
}

main(
  fold_path = opt[["--fold_path"]],
  label = opt[["--label"]],
  prefix = opt[["--prefix"]],
  method_name = opt[["--method_name"]]
)
```

#### Python Implementation Example

```python
#!/usr/bin/env python

"""Train <method> model

Usage:
  <method>_train.py [options]

Options:
  --fold_path=FOLD_PATH     Path to fold directory
  --label=LABEL             Dataset-fold label [default: data]
  --method_name=METHOD_NAME Method name [default: <method>]
"""

from docopt import docopt
import os
import pickle
import mudata
import numpy as np

def main(fold_path, label, method_name):
    print(f"Training fold: {fold_path}")
    
    # Find train/test paths
    files = os.listdir(fold_path)
    train_path = [f for f in files if "_tr" in f][0]
    test_path = [f for f in files if "_te" in f][0]
    
    # Load data
    train_mu = mudata.read(os.path.join(fold_path, train_path))
    test_mu = mudata.read(os.path.join(fold_path, test_path))
    
    # Extract features and labels
    # Assumes 'y' or 'response' column in obs
    y_train = train_mu.obs['y'].values
    
    # YOUR METHOD TRAINING LOGIC HERE
    # Example: Combine modalities and train
    # X_train = np.concatenate([train_mu[mod].X for mod in train_mu.mod.keys()], axis=1)
    # model = YourMethod()
    # model.fit(X_train, y_train)
    
    # Placeholder
    model = {"method": method_name}
    
    # Save outputs
    model_file = f"{label}-{method_name}_model.pkl"
    test_file = f"{label}-test_data.pkl"
    
    with open(model_file, 'wb') as f:
        pickle.dump(model, f)
    with open(test_file, 'wb') as f:
        pickle.dump(test_mu, f)
    
    print("Training complete")

if __name__ == "__main__":
    args = docopt(__doc__)
    main(
        fold_path=args["--fold_path"],
        label=args["--label"],
        method_name=args["--method_name"]
    )
```

**Expected Outputs:**
- `<dataset>-<fold>-<method>_model.{rds,pkl}` - Trained model
- `<dataset>-<fold>-test_data.{rds,pkl}` - Test data for prediction
- `<dataset>-<fold>-<method>_train.log` - Log file

---

### Step 5: Implement Prediction/Testing

**Purpose**: Generate predictions on test data using the trained model.

**File Location**: `modules/<method>/predict/resources/usr/bin/<method>_predict.{R,py}`

#### R Implementation Example

```r
#!/usr/bin/env Rscript

doc <- "Predict using <method> model

Usage:
  <method>_predict.R [options]

Options:
  --model_path=MODEL_PATH   Path to trained model
  --test_path=TEST_PATH     Path to test data
  --label=LABEL             Dataset-fold label [default: data]
  --method_name=METHOD_NAME Method name [default: <method>]
"

library(dplyr)
opt <- docopt::docopt(doc)

main <- function(model_path, test_path, label, method_name) {
  cat("Predicting for:", label, "\n")
  
  # Load model and test data
  model <- readRDS(model_path)
  test_data <- readRDS(test_path)
  
  # YOUR PREDICTION LOGIC HERE
  # Example:
  # X_test <- do.call(cbind, test_data$X)
  # predictions <- predict(model, newdata=X_test, type="response")
  
  # Placeholder
  predictions <- runif(length(test_data$y))
  
  # Create results table with REQUIRED columns
  results <- data.frame(
    sample_name = test_data$sample_names,  # Sample identifiers
    y = test_data$y,                        # True labels (0 or 1)
    phat = predictions,                     # Predicted probability P(Y=1)
    method_name = method_name,              # Method name
    dataset = strsplit(label, "-")[[1]][1]  # Dataset name
  )
  
  # Save results
  result_file <- paste0(label, "-result_table.csv")
  write.csv(results, result_file, row.names = FALSE)
  
  cat("Prediction complete\n")
}

main(
  model_path = opt[["--model_path"]],
  test_path = opt[["--test_path"]],
  label = opt[["--label"]],
  method_name = opt[["--method_name"]]
)
```

#### Python Implementation Example

```python
#!/usr/bin/env python

"""Predict using <method> model

Usage:
  <method>_predict.py [options]

Options:
  --model_path=MODEL_PATH       Path to trained model
  --test_path=TEST_PATH         Path to test data
  --metadata_path=METADATA_PATH Path to metadata
  --label=LABEL                 Dataset-fold label [default: data]
  --method_name=METHOD_NAME     Method name [default: <method>]
"""

from docopt import docopt
import pickle
import pandas as pd

def main(model_path, test_path, metadata_path, label, method_name):
    print(f"Predicting for: {label}")
    
    # Load model and test data
    with open(model_path, 'rb') as f:
        model = pickle.load(f)
    with open(test_path, 'rb') as f:
        test_data = pickle.load(f)
    with open(metadata_path, 'rb') as f:
        metadata = pickle.load(f)
    
    # YOUR PREDICTION LOGIC HERE
    # Example:
    # X_test = np.concatenate([test_data[mod].X for mod in test_data.mod.keys()], axis=1)
    # predictions = model.predict_proba(X_test)[:, 1]
    
    # Placeholder
    predictions = [0.5] * len(metadata)
    
    # Create results table with REQUIRED columns
    results = pd.DataFrame({
        'sample_name': metadata['sample_name'],     # Sample identifiers
        'y': metadata['y'],                          # True labels (0 or 1)
        'phat': predictions,                         # Predicted probability P(Y=1)
        'method_name': method_name,                  # Method name
        'dataset': label.split('-')[0]               # Dataset name
    })
    
    # Save results
    result_file = f"{label}-result_table.csv"
    results.to_csv(result_file, index=False)
    
    print("Prediction complete")

if __name__ == "__main__":
    args = docopt(__doc__)
    main(
        model_path=args["--model_path"],
        test_path=args["--test_path"],
        metadata_path=args["--metadata_path"],
        label=args["--label"],
        method_name=args["--method_name"]
    )
```

**CRITICAL - Required Output Columns:**

The result CSV **must** contain these exact columns:

| Column | Description | Type | Example |
|--------|-------------|------|---------|
| `sample_name` | Patient/sample identifier | string | "patient-1", "SR12" |
| `y` | True class label | binary (0/1) | 0, 1 |
| `phat` | Predicted probability of y=1 | float [0,1] | 0.243, 0.78 |
| `method_name` | Name of the method | string | "diablo", "mogonet" |
| `dataset` | Dataset name | string | "ROSMAP", "TCGA" |

---

### Step 6: Implement Feature Selection (Optional)

**Purpose**: Identify important features from the multiomics data.

**File Location**: `modules/<method>/select_feature/resources/usr/bin/<method>_select_feature.{R,py}`

This process is **optional**. Only implement if your method provides feature selection/importance.

#### Example Structure

```r
#!/usr/bin/env Rscript

doc <- "Select features using <method>

Usage:
  <method>_select_feature.R [options]

Options:
  --dataset_name=NAME       Dataset name
  --data_path=DATA_PATH     Path to data
"

opt <- docopt::docopt(doc)

main <- function(dataset_name, data_path) {
  # YOUR FEATURE SELECTION LOGIC
  # ...
  
  # Output: CSV with selected features
  # Format: feature_name, importance_score, modality
  features <- data.frame(
    feature_name = c("gene1", "cpg2"),
    importance = c(0.95, 0.87),
    modality = c("transcriptomics", "epigenomics")
  )
  
  write.csv(features, paste0(dataset_name, "_selected_features.csv"), row.names=FALSE)
}

main(dataset_name=opt$dataset_name, data_path=opt$data_path)
```

---

### Step 7: Integrate into CV Workflow

The template generator automatically adds your method to the appropriate cross-validation workflow.

#### For R Methods: `subworkflows/cross_validation/r/main.nf`

The generator adds:

```groovy
// 1. Include statement (top of file)
include { MY_METHOD } from "${subworkflowDir}/methods/my_method"

// 2. Skip parameter (in main section)
skip_my_method = params.skip_my_method // boolean: true/false

// 3. Instantiation block (in main section)
my_method_results = Channel.empty()
if (!skip_my_method) {
    MY_METHOD ( mae_copy )
    my_method_results = MY_METHOD.out.csv_results
}

// 4. Output mixing (in output collection)
.mix( my_method_results )
```

#### For Python Methods: `subworkflows/cross_validation/python/main.nf`

Similar structure, but uses `mu_copy` instead of `mae_copy`.

#### Manual Configuration

Add to `nextflow.config` or command line to enable/disable:

```groovy
params {
    skip_my_method = false  // Set to true to skip this method
}
```

---

### Step 8: Build and Test

#### 1. Build Container

```bash
# Build
docker build -f containers/dockerfiles/<method>.Dockerfile \
  -t <user>/<method>:latest .

# Push
docker push <user>/<method>:latest

# For HPC
apptainer pull <method>.sif docker://<user>/<method>:latest
```

#### 2. Test Locally

```bash
# Test with small dataset
nextflow run main.nf \
  --input test_data/samplesheet.csv \
  --outdir results_test \
  --skip_all_except_<method>
```

#### 3. Debug Individual Processes

```bash
# Test preprocessing only
nextflow run main.nf -entry test_preprocess \
  --method <method> \
  -stub-run  # Use stub mode for quick checks
```

#### 4. Check Outputs

Verify output structure:
```
results/
├── <method>_preprocess/<dataset>/
│   ├── fold_1/
│   │   ├── fold_1_tr/
│   │   └── fold_1_te/
│   └── fold_2/
├── <method>_train/<dataset>/
│   ├── fold_1/
│   │   └── <dataset>-fold_1-<method>_model.{rds,pkl}
│   └── fold_2/
└── <method>_predict/<dataset>/
    ├── fold_1/
    │   └── <dataset>-fold_1-result_table.csv
    └── fold_2/
```

---

## Method Components Overview

### Required Files

```
MESSI-pipeline/
├── containers/dockerfiles/<method>.Dockerfile
├── subworkflows/methods/<method>/main.nf
└── modules/<method>/
    ├── preprocess/
    │   ├── main.nf
    │   └── resources/usr/bin/<method>_preprocess.{R,py}
    ├── train/
    │   ├── main.nf
    │   └── resources/usr/bin/<method>_train.{R,py}
    ├── predict/
    │   ├── main.nf
    │   └── resources/usr/bin/<method>_predict.{R,py}
    └── select_feature/  # Optional
        ├── main.nf
        └── resources/usr/bin/<method>_select_feature.{R,py}
```

### Data Flow

```
1. PREPROCESS
   Input:  Full dataset + split indices
   Output: fold_N/fold_N_{tr,te}/ directories
   
2. TRAIN
   Input:  fold_N/ directory
   Output: model file + test_data file
   
3. PREDICT
   Input:  model file + test_data file
   Output: result_table.csv
   
4. MERGE_RESULT_TABLE
   Input:  All result_table.csv files
   Output: Combined results for downstream analysis
```

---

## Language-Specific Details

### R Methods

**Data Format**: MultiAssayExperiment (MAE)
- Structure: `p_i x N` (features × samples)
- File format: HDF5-backed MAE saved with `saveHDF5MultiAssayExperiment()`

**Key Libraries:**
```r
library(MultiAssayExperiment)
library(HDF5Array)
library(docopt)
library(here)
```

**Base Docker Image**: `tonyliang19/r_method_base_dev`

**Workflow**: `subworkflows/cross_validation/r/main.nf`

**Input Channel**: `mae_copy`

### Python Methods

**Data Format**: MuData
- Structure: `N x p_i` (samples × features)
- File format: `.h5mu` files

**Key Libraries:**
```python
import mudata
import numpy as np
import pandas as pd
from docopt import docopt
```

**Base Docker Image**: Custom Python 3.9+ image

**Workflow**: `subworkflows/cross_validation/python/main.nf`

**Input Channel**: `mu_copy`

---

## Troubleshooting

### Common Issues

#### 1. "Container not found"

**Problem**: Nextflow can't find the container.

**Solution**: 
- Ensure container is pushed to DockerHub
- For HPC: Place `.sif` file in correct directory
- Check container name in process matches your DockerHub image

#### 2. "Script not executable"

**Problem**: Binary scripts lack execute permission.

**Solution**:
```bash
chmod +x modules/<method>/*/resources/usr/bin/*
git add --chmod=+x modules/<method>/*/resources/usr/bin/*
```

#### 3. "Missing shebang"

**Problem**: Scripts don't start with `#!/usr/bin/env ...`

**Solution**: Add to first line of each script:
- R: `#!/usr/bin/env Rscript`
- Python: `#!/usr/bin/env python`

#### 4. "Output files not created"

**Problem**: Process completes but expected outputs missing.

**Solution**:
- Check script output locations match Nextflow `output` block
- Verify file naming conventions
- Check logs: `work/<hash>/.command.log`

#### 5. "Wrong data format"

**Problem**: Method expects different data shape.

**Solution**: Add transpose in preprocessing:
```r
# R: Transpose if needed
X_transposed <- lapply(mae@ExperimentList, t)
```

```python
# Python: Transpose if needed
X_transposed = mdata.mod[mod].X.T
```

#### 6. "Missing required columns in result table"

**Problem**: Prediction output CSV missing required columns.

**Solution**: Ensure output has exactly:
- `sample_name`
- `y`
- `phat`
- `method_name`
- `dataset`

### Getting Help

1. **Check existing methods**: Look at `demo_logit`, `sklearn`, or `diablo` for examples
2. **Review logs**: Check `.nextflow.log` and `work/` directories
3. **Use stub mode**: Test with `-stub-run` for quick iterations
4. **Enable debug**: Set `params.debug = true` in config

---

## Summary Checklist

When adding a method, ensure:

- [ ] Dockerfile created and container pushed to DockerHub
- [ ] Template generated with `adding_method.py`
- [ ] Preprocessing script implemented
  - [ ] Splits data into folds
  - [ ] Outputs correct directory structure
  - [ ] Script is executable with shebang
- [ ] Training script implemented
  - [ ] Trains model on fold
  - [ ] Outputs model and test data files
  - [ ] Script is executable with shebang
- [ ] Prediction script implemented
  - [ ] Generates predictions
  - [ ] Outputs CSV with required 5 columns
  - [ ] Script is executable with shebang
- [ ] Feature selection implemented (if applicable)
- [ ] Method integrated into CV_R or CV_PYTHON workflow
- [ ] All scripts use `docopt` for argument parsing
- [ ] Container paths correct in `main.nf` files
- [ ] Method tested locally
- [ ] Documentation updated

---

## Additional Resources

- **Existing R Method Example**: `docs/tutorials/adding_r-based_method/adding_r-based_method.md`
- **Preprocessing Guide**: `docs/tutorials/preprocessing/R/preprocesing.md`
- **Template Files**: `bin/adding_method/messi_add_method/method-template/`
- **Container Guide**: `containers/README.md`
- **Main Pipeline Docs**: `README.md`
