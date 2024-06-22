Preprocessing step
================
15 April, 2024

``` r
library(here)
```

    ## here() starts at C:/Users/chunq/Desktop/project/multi-omics-pipeline

``` r
# BiocManage::install("MultiAssayExperiment")
# BiocManager::install("HDF5Array")
library(MultiAssayExperiment)
```

    ## Loading required package: SummarizedExperiment

    ## Loading required package: MatrixGenerics

    ## Loading required package: matrixStats

    ## 
    ## Attaching package: 'MatrixGenerics'

    ## The following objects are masked from 'package:matrixStats':
    ## 
    ##     colAlls, colAnyNAs, colAnys, colAvgsPerRowSet, colCollapse,
    ##     colCounts, colCummaxs, colCummins, colCumprods, colCumsums,
    ##     colDiffs, colIQRDiffs, colIQRs, colLogSumExps, colMadDiffs,
    ##     colMads, colMaxs, colMeans2, colMedians, colMins, colOrderStats,
    ##     colProds, colQuantiles, colRanges, colRanks, colSdDiffs, colSds,
    ##     colSums2, colTabulates, colVarDiffs, colVars, colWeightedMads,
    ##     colWeightedMeans, colWeightedMedians, colWeightedSds,
    ##     colWeightedVars, rowAlls, rowAnyNAs, rowAnys, rowAvgsPerColSet,
    ##     rowCollapse, rowCounts, rowCummaxs, rowCummins, rowCumprods,
    ##     rowCumsums, rowDiffs, rowIQRDiffs, rowIQRs, rowLogSumExps,
    ##     rowMadDiffs, rowMads, rowMaxs, rowMeans2, rowMedians, rowMins,
    ##     rowOrderStats, rowProds, rowQuantiles, rowRanges, rowRanks,
    ##     rowSdDiffs, rowSds, rowSums2, rowTabulates, rowVarDiffs, rowVars,
    ##     rowWeightedMads, rowWeightedMeans, rowWeightedMedians,
    ##     rowWeightedSds, rowWeightedVars

    ## Loading required package: GenomicRanges

    ## Loading required package: stats4

    ## Loading required package: BiocGenerics

    ## 
    ## Attaching package: 'BiocGenerics'

    ## The following objects are masked from 'package:stats':
    ## 
    ##     IQR, mad, sd, var, xtabs

    ## The following objects are masked from 'package:base':
    ## 
    ##     anyDuplicated, aperm, append, as.data.frame, basename, cbind,
    ##     colnames, dirname, do.call, duplicated, eval, evalq, Filter, Find,
    ##     get, grep, grepl, intersect, is.unsorted, lapply, Map, mapply,
    ##     match, mget, order, paste, pmax, pmax.int, pmin, pmin.int,
    ##     Position, rank, rbind, Reduce, rownames, sapply, setdiff, sort,
    ##     table, tapply, union, unique, unsplit, which.max, which.min

    ## Loading required package: S4Vectors

    ## 
    ## Attaching package: 'S4Vectors'

    ## The following object is masked from 'package:utils':
    ## 
    ##     findMatches

    ## The following objects are masked from 'package:base':
    ## 
    ##     expand.grid, I, unname

    ## Loading required package: IRanges

    ## 
    ## Attaching package: 'IRanges'

    ## The following object is masked from 'package:grDevices':
    ## 
    ##     windows

    ## Loading required package: GenomeInfoDb

    ## Loading required package: Biobase

    ## Welcome to Bioconductor
    ## 
    ##     Vignettes contain introductory material; view with
    ##     'browseVignettes()'. To cite Bioconductor, see
    ##     'citation("Biobase")', and for packages 'citation("pkgname")'.

    ## 
    ## Attaching package: 'Biobase'

    ## The following object is masked from 'package:MatrixGenerics':
    ## 
    ##     rowMedians

    ## The following objects are masked from 'package:matrixStats':
    ## 
    ##     anyMissing, rowMedians

``` r
# Parameters used
# Directory that has the mae and rds inside it (so actual data)
raw_mae_dir <- here("data/tutorial_data/tutorial_mae_data/")
# Pre-splitted indices store in txt files
raw_split_dir <- here("data/tutorial_data/splits/")
# This dataset name is usually given inside the pipeline by parsing
# the data directory
dataset_name <- "tutorial"
```

The first step for implementing a method, is to write any preprocessing
steps required for the method, i.e. any math transformation or any of
labelling changes or any kinds of preprocessing steps required by a
method to use.

It should accept 3 inputs

1.  Path to directory of mae data (so this path is dir that contains mae
    and rds)
2.  Path to directory of txt files of test indices, having K txts, where
    K is your number of folds, and each txt having ${N_{k_{i}}}$ folds
3.  Label of the dataset, its name

If there’s nothing special to be transformed or done to the original
data, then you could likely skip this part, and use the
~/bin/split_mae.R instead.

The sample `split_mae.R` looks like this:

``` r
# ==============================================================================
# This is a sample split_mae.R
#Usage:
#  split_mae.R [options]
#
#Options:
# --mae_path=MAE_PATH     Path containing full data inside MAE  [default: empty]
# --split_dir=SPLIT_DIR   Directory containing list of txt file [default: empty]
# --dataset_name=NAME     Name of dataset that is splitting     [default: empty]
# --transpose             Transpose the data as method requires [default: False]
# ==============================================================================
# And its content having two wrapper functions
# 1. Load the txt files and parse it to a list object
#    with functionality of checking if 0-indexed and reindex it
#    to 1-indexed
load_test_splits <- function(split_dir, pattern=".txt", ...) {
  if (split_dir == "empty") {
    stop("You did not provide the directory that contains txt files of indices")
  }
  # Glob pattern
  # The split dir needs to be relative, do NOT use here::here
  # When run with nextflow, as it caches the dir inside a work directory
  idx_files <- list.files(path=split_dir, 
                          pattern=".txt", full.names = TRUE)
  # Read in data
  idx_list <- lapply(idx_files, function(f) {
    data <- scan(f, what = numeric(), quiet = TRUE)
    return(data)
  })
  
  # Check if it contains zero (hence assume it was 0index based)
  zero_indexed <- any(sapply(idx_list, function(vec) any(vec == 0)))
  # Then if true, shift all by 1
  if (zero_indexed) {
    cat("\nIndex founded to be 0 based, shift by 1 for all\n")
    idx_list <- lapply(idx_list, function(x) x + 1)
  }
  
  # Assign names based on loaded files
  idx_list <- setNames(idx_list, 
                       tools::file_path_sans_ext(basename(idx_files)))
  return(idx_list)
}

# Then we could call it to load test splits as list
test_splits <- load_test_splits(split_dir = raw_split_dir)



# 2. Load the mae from disk, and for each fold we found earlier,
#   split each fold to a directory, such that dir contains the train
#   and test portion maes. So train-mae-f_i + test-mae-f_i = mae-f_i
#   where mae-f_i means i-th fold mae data
#   This function already calls the previous load_test_splits function
split_mae <- function(mae_path, split_dir, dataset_name) {
  # Read in the MAE
  # Note the prefix "" is required here?
  mae <- MultiAssayExperiment::loadHDF5MultiAssayExperiment(dir=mae_path, prefix="")
  # Should be a list of splits
  cat("Splitting data for", dataset_name, "\n")
  cat("\nThe data is located in:", mae_path, "\n")
  cat("\nThe splits are located in:", split_dir, "\n")
  test_splits <- load_test_splits(split_dir=split_dir)
  fold_names <- names(test_splits)
  for (fold_name in fold_names) {
    # First subset both
    split <- test_splits[[fold_name]]
    # TODO: Transpose data only when method requires it to
    tr_mae <- mae[, -split, drop=TRUE]
    te_mae <- mae[, split, drop=TRUE]
    # Then save each fold's train and test portion as subdirectory of fold name
    cat("\nSaving for", fold_name, "\n")
    if (!dir.exists(fold_name)) {
      dir.create(fold_name)
    }
    tr_path <- file.path(fold_name, paste0(fold_name, "_tr"))
    te_path <- file.path(fold_name, paste0(fold_name, "_te"))
    # The train portion
    MultiAssayExperiment::saveHDF5MultiAssayExperiment(tr_mae, dir=tr_path,
                                                       prefix="train")
    # The test portion
    MultiAssayExperiment::saveHDF5MultiAssayExperiment(te_mae, dir=te_path,
                                                       prefix="test")
    cat("\nSaved for", fold_name, "\n")                                                      
  }
}
# This already calls load_test_split in it
split_mae(mae_path = raw_mae_dir, split_dir = raw_split_dir, 
          dataset_name = dataset)
```

We could actually run it, and these are their outputs. So, using some
tutorial data located at `~/data/tutorial_data`

``` r
# 1. Load the txt files and parse it to a list object
#    with functionality of checking if 0-indexed and reindex it
#    to 1-indexed
load_test_splits <- function(split_dir, pattern=".txt", ...) {
  if (split_dir == "empty") {
    stop("You did not provide the directory that contains txt files of indices")
  }
  # Glob pattern
  # The split dir needs to be relative, do NOT use here::here
  # When run with nextflow, as it caches the dir inside a work directory
  idx_files <- list.files(path=split_dir, 
                          pattern=".txt", full.names = TRUE)
  # Read in data
  idx_list <- lapply(idx_files, function(f) {
    data <- scan(f, what = numeric(), quiet = TRUE)
    return(data)
  })
  
  # Check if it contains zero (hence assume it was 0index based)
  zero_indexed <- any(sapply(idx_list, function(vec) any(vec == 0)))
  # Then if true, shift all by 1
  if (zero_indexed) {
    cat("\nIndex founded to be 0 based, shift by 1 for all\n")
    idx_list <- lapply(idx_list, function(x) x + 1)
  }
  
  # Assign names based on loaded files
  idx_list <- setNames(idx_list, 
                       tools::file_path_sans_ext(basename(idx_files)))
  return(idx_list)
}

# Load the test indices of each fold
load_test_splits(raw_split_dir)
```

    ## 
    ## Index founded to be 0 based, shift by 1 for all

    ## $fold_1
    ##  [1]  5  8  9 10 12 15 16 25 31 34 35 37 39 40 43 44 45
    ## 
    ## $fold_2
    ##  [1]  3  6 11 13 18 19 20 22 29 30 32 33 38 42 46 49 50
    ## 
    ## $fold_3
    ##  [1]  1  2  4  7 14 17 21 23 24 26 27 28 36 41 47 48

``` r
# 2. Load the mae from disk, and for each fold we found earlier,
#   split each fold to a directory, such that dir contains the train
#   and test portion maes. So train-mae-f_i + test-mae-f_i = mae-f_i
#   where mae-f_i means i-th fold mae data
#   This function already calls the previous load_test_splits function
split_mae <- function(mae_path, split_dir, dataset_name) {
  # Read in the MAE
  # Note the prefix "" is required here?
  mae <- MultiAssayExperiment::loadHDF5MultiAssayExperiment(dir=mae_path, prefix="")
  # Should be a list of splits
  message("Splitting data for", dataset_name, "\n")
  message("\nThe data is located in:", mae_path, "\n")
  message("\nThe splits are located in:", split_dir, "\n")
  test_splits <- load_test_splits(split_dir=split_dir)
  fold_names <- names(test_splits)
  for (fold_name in fold_names) {
    # First subset both
    split <- test_splits[[fold_name]]
    # TODO: Transpose data only when method requires it to
    tr_mae <- mae[, -split, drop=TRUE]
    te_mae <- mae[, split, drop=TRUE]
    # Then save each fold's train and test portion as subdirectory of fold name
    cat("\nSaving for", fold_name, "\n")
    if (!dir.exists(fold_name)) {
      dir.create(fold_name)
    }
    tr_path <- file.path(fold_name, paste0(fold_name, "_tr"))
    te_path <- file.path(fold_name, paste0(fold_name, "_te"))
    # The train portion
    MultiAssayExperiment::saveHDF5MultiAssayExperiment(tr_mae, dir=tr_path,
                                                       prefix="train")
    # The test portion
    MultiAssayExperiment::saveHDF5MultiAssayExperiment(te_mae, dir=te_path,
                                                       prefix="test")
    message("\nSaved for", fold_name, "\n")                                                      
  }
}
# This already calls load_test_split in it
# NOTE: this required HDF5Array installed as well
split_mae(mae_path = raw_mae_dir, split_dir = raw_split_dir, 
          dataset_name = dataset_name)
```

    ## Splitting data fortutorial

    ## 
    ## The data is located in:C:/Users/chunq/Desktop/project/multi-omics-pipeline/data/tutorial_data/tutorial_mae_data

    ## 
    ## The splits are located in:C:/Users/chunq/Desktop/project/multi-omics-pipeline/data/tutorial_data/splits

    ## 
    ## Index founded to be 0 based, shift by 1 for all
    ## 
    ## Saving for fold_1

    ## 
    ## Saved forfold_1

    ## 
    ## Saving for fold_2

    ## 
    ## Saved forfold_2

    ## 
    ## Saving for fold_3

    ## 
    ## Saved forfold_3
