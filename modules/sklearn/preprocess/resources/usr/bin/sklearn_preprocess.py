#!/usr/bin/env python

"""
This script is to preprocess and prepare input for sklearn training,
including data format transformation, scaling or NA handlings

Usage:
  sklearn_preprocess.py [options]

Options:
  --help                          Display this help message
  --data_path=DATA_PATH           Path to MuData [default: empty]
  --split_dir=SPLIT_DIR           Path to all the splits [default: splits]
  --dataset_name=DNAME            Name of the dataset
"""

# TODO: You might need to add more args into your docopt message above

# Imports goes here
from docopt import docopt
import os
import glob
import numpy as np
import pandas as pd
import mudata

# Custom imports
from load_test_splits import load_test_splits
from tr_te_split_mdata import tr_te_split_mdata

# This is the main logic
# TODO: You likely need to implement this main function
def main(mdata_path, split_dir, dataset_name, base_dir="fold", ext="h5mu"):
    # Load the mudata
    mdata = mudata.read(mdata_path)
    # Notice index here is 0-based (read in txts)
    test_splits_df = load_test_splits(split_dir)
    # For each split we want to partitioned the mdata and save each directory including its train and test fold
    # Like fold_1/
    #      |_____ fold_1_tr_mdata.h5mu
    #      |_____ fold_1_te_mdata.h5mu
    for i, split in enumerate(test_splits_df.index):
        # Create output folder first
        outdir = f"{base_dir}_{i+1}"
        os.makedirs(outdir, exist_ok=True)
        # Set filename for train and test mudata
        train_file = f"{outdir}/{dataset_name}-train_mu.{ext}"
        test_file  = f"{outdir}/{dataset_name}-test_mu.{ext}"
        # Split the original mudata to train and test portion
        train_mu, test_mu, = tr_te_split_mdata(mdata, splits_df=test_splits_df, split=split)
        # Then write these individual h5mu out to disk
        train_mu.write_h5mu(train_file)
        test_mu.write_h5mu(test_file)
    return None

# Execute it here
if __name__ == '__main__':
  # Parse docopt
  args = docopt(__doc__)
  # Execute runner
  main(
    mdata_path      = args["--data_path"],
    split_dir       = args["--split_dir"],
    dataset_name    = args['--dataset_name']
  )