#!/usr/bin/env python

"""
This script is to preprocess and prepare input for {{ method|lower }} training,
including data format transformation, scaling or NA handlings

Usage:
  {{ method|lower }}_preprocess.py [options]

Options:
  --help                          Display this help message
  --mdata_path=MDATA              Path to MuData [default: empty]
  --splits_dir=SPLITS_DIR         Path to all the splits [default: splits]
"""

# TODO: You might need to add more args into your docopt message above

# Imports goes here
from docopt import docopt
import os
import glob
import numpy as np
import pandas as pd
import mudata


# Helper to run the splits from list of txts files
def load_test_splits(splits_dir, pattern="*fold*"):
  """
  Parameters:
    splits_dir:   Directory containing test indices pre splitted earlier

  Return:
    out_df: a dataframe, with index being test_fold_i for i to k
            each row is an array of index indicating which original
            row of data was "test" data
  """
  # Requires pattern to match multiple files
  files = glob.glob(os.path.join(splits_dir, pattern))
  split_dict = {}
  for index, file in enumerate(files):
      # Note we need to shift these back to 0 index
      # idxs = [x - 1 for x in np.loadtxt(f).astype(int)]
      test_idxs = np.loadtxt(file).astype(int) # Load them as integer from numpy
      label = f"test_fold_split_{index+1}"
      split_dict[label] = test_idxs
  out_df = pd.DataFrame([split_dict]).T.rename(columns={0:"test_indices"})
  return out_df

# Helper fun to merge and retrieve metadata from MuData
def merge_obs_metadata(df):
    # Check common cols
    split_cols = df.columns.str.split(':', expand=True)
    unique_cols = split_cols.get_level_values(1).unique()
    # Drop those duplicated values on columns of each block
    df = df.T.drop_duplicates().T
    # Rename cols
    df.columns = unique_cols
    return df

# Helper fun to split the provide MuData into train.test MuData
# Return data as of scikit learn way, but put together as train, test
# where train = (train_mu, train_y), and test = (test_mu, test_y)
def tr_te_mdata(mdata, splits_df, meta, split):
    test_idx = splits_df.loc[split].iloc[0]
    # Get the rest idxs except those in current split, sorted
    train_idx = sorted(splits_df[splits_df.index != split].test_indices.explode().tolist())
    # Get train and test copy
    train_mu, test_mu = mdata[train_idx].copy(), mdata[test_idx].copy()
    # Add this metadata for downstream access
    cols_interest = ["sample_name", "y"]
    test_meta = meta.reset_index(drop=True).rename(columns={"sample_names": "sample_name",
                                                            "response": "y"})
    test_meta = test_meta[cols_interest].loc[test_idx]
    ## Get the response from obs aswell
    # TODO: need to check this bit below
    y = meta["response"].values
    if (isinstance(y[0], str)):
        bin = lambda y: 1 if y == "yes" else 0
        y = np.vectorize(bin)(y)
    # Check if binary otherwise 
    # Transform it to binary
    #bin = lambda y: 1 if y == "yes" else 0
    #y = np.vectorize(bin)(y)
    train_y, test_y = y[train_idx], y[test_idx]
    # Return as output joined together
    return (train_mu, train_y), (test_mu, test_y), test_meta

# This is the main logic
# TODO: You likely need to implement this main function
def main(mdata_path, splits_dir, base_dir="fold"):
    mdata = mudata.read(mdata_path)
    # Notice index here is 0-based (read in txts)
    test_splits_df  =  load_test_splits(splits_dir=splits_dir)
    metadata_df     =  merge_obs_metadata(mdata.obs)
    for i, split in enumerate(test_splits_df.index):
        # Create output folder first
        outdir = f"{base_dir}_{i+1}"
        os.makedirs(outdir, exist_ok=True)
        # Extract X,y combination of train and test data
        train, test, meta_test = tr_te_mdata(mdata, test_splits_df, meta=metadata_df, split=split)
        # For each train and test we need to split the blocks out and their labels
        # The input is always comes in X , y combination
        # TODO: You might need to convert these train, test mudata into torch like tensors
        # TODO: You need to write out processed data in the outdir above for all splits from 1 to K.
    return None

# Execute it here
if __name__ == '__main__':
  # Parse docopt
  args = docopt(__doc__)
  # Execute runner
  main(
    mdata_path      = args["--mdata_path"],
    splits_dir      = args["--splits_dir"],
    base_dir        = args["--base_dir"]
  )