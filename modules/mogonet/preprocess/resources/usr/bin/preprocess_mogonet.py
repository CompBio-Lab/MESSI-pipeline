#!/usr/bin/env python

"""
This script is to preprocess and prepare input for MOGONET training,
it relies on custom scripts to handle some logic.

Usage:
  preprocess_mogonet.py [options]

Options:
  --help                          Display this help message
  --mdata_path=MDATA              Path to MuData [default: empty]
  --splits_dir=SPLITS_DIR         Path to all the splits [default: empty]
  --base_dir=BASE_DIR             Directory to store mogonet input data [default: fold]
"""
# Imports goes here
from docopt import docopt
import os
import numpy as np
import pandas as pd
import mudata
# Custom script import
from load_test_splits   import  load_test_splits
from tr_te_mdata        import  tr_te_mdata
from save_metadata      import  save_metadata
from save_blocks_labels import  save_blocks_labels
from merge_obs_metadata import  merge_obs_metadata
# For each split of the folds do the following

# This is the main runner
def prepare_mogonet_input(mdata_path, splits_dir, base_dir):
    mdata = mudata.read(mdata_path)
    # Notice index here is 0-based (read in txts)
    test_splits_df = load_test_splits(splits_dir=splits_dir)
    obs_df = merge_obs_metadata(mdata.obs)
    for i, split in enumerate(test_splits_df.index):
        # Create output folder first
        outdir = f"{base_dir}_{i+1}"
        os.makedirs(outdir, exist_ok=True)
        # Note the obs metadata is going to have repeated info, given
        # each block has the same sample_names, response, age, so need to combine those
        # obs_df = merge_obs_metadata(mdata.obs)
        # Then need to split blocks and   labels
        train, test, meta_test = tr_te_mdata(mdata, test_splits_df, meta=obs_df, split=split)
        # For each train and test we need to split the blocks out and their labels
        # The input is always comes in X , y combination
        print(f"Saving metadata for test set for {split}")
        save_metadata(meta_test, i+1, outdir)
        print(f"Saving blocks and labels for {split}")
        save_blocks_labels(train, test, outdir)
    print(f"Done preparing mogonet inputs")
    return "Done"

# Execute it here
if __name__ == '__main__':
  # Parse docopt
  args = docopt(__doc__)
  # Execute runner
  prepare_mogonet_input(
    mdata_path      = args["--mdata_path"],
    splits_dir      = args["--splits_dir"],
    base_dir        = args["--base_dir"]
  )