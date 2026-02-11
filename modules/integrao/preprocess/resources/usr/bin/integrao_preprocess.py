#!/usr/bin/env python

"""
This script is to preprocess and prepare input for integrao training,
including data format transformation, scaling or NA handlings

Usage:
  integrao_preprocess.py [options]

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
import mudata as md
import json

def load_mudata(input_path):
    """Load MuData and extract modality names.

    Parameters
    ----------
    input_path : str
        Path to .h5mu file.

    Returns
    -------
    mdata : mudata.MuData
        Loaded MuData object.
    modality_names : list of str
        Names of modalities present in the MuData.
    """
    mdata = md.read(input_path)
    modality_names = list(mdata.mod.keys())
    print(f"Loaded MuData with modalities: {modality_names}")
    print(f"Total samples: {mdata.n_obs}")
    return mdata


# Helper to run the splits from list of txts files
def load_test_splits(split_dir, pattern="*fold*"):
  """
  Parameters:
    split_dir:   Directory containing test indices pre splitted earlier

  Return:
    out_df: a dataframe, with index being test_fold_i for i to k
            each row is an array of index indicating which original
            row of data was "test" data
  """
  # Requires pattern to match multiple files
  files = glob.glob(os.path.join(split_dir, pattern))
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
    # And renaming columns
    df = df.rename(columns={"sample_names": "sample_name", "response": "y"})
    # And map the values of y to 1 and 0
    df["y"] = df["y"].map({"yes":1, "no": 0})
    return df


# Helper fun to split the provide MuData into train.test MuData
def tr_te_mdata(mdata, splits_df, split):
    test_idx = splits_df.loc[split].iloc[0]
    # Get the rest idxs except those in current split, sorted
    train_idx = sorted(splits_df[splits_df.index != split].test_indices.explode().tolist())
    # Get train and test copy
    train_mu, test_mu = mdata[train_idx].copy(), mdata[test_idx].copy()
    return train_mu, test_mu

def get_parameters_json(mdata, metadata_df, split):
    metadata = {
        "modality_names": list(mdata.mod.keys()),
        "num_classes": len(metadata_df["y"].unique()),
        "fold": split
    }
    return metadata


def save_preprocessed(outdir, train_mdata, test_mdata, mdata, metadata):
    """Save all preprocessed outputs to disk.
    """
    os.makedirs(outdir, exist_ok=True)

    train_mdata.write(os.path.join(outdir, "train_data.h5mu"))
    test_mdata.write(os.path.join(outdir, "test_data.h5mu"))
    mdata.write(os.path.join(outdir, "full_data.h5mu"))
    with open(os.path.join(outdir, "metadata.json"), "w") as f:
        json.dump(metadata, f, indent=2, default=str)

    print(f"Preprocessing complete. Outputs in {outdir}")



# This is the main logic
# TODO: You likely need to implement this main function
def main(mdata_path, dataset_name, split_dir, base_dir="fold"):
    mdata           = load_mudata(mdata_path)
    test_splits_df  = load_test_splits(split_dir=split_dir)
    metadata_df     = merge_obs_metadata(mdata.obs)
    # Then loop through the splits and do the preprocessing and save the output
    for i, split in enumerate(test_splits_df.index):
        # Create output folder first
        outdir = f"{base_dir}_{i+1}"
        print(f"Processing fold{i+1}")
        os.makedirs(outdir, exist_ok=True)
        train_mdata, test_mdata = tr_te_mdata(mdata, test_splits_df, split=split)
        parameters_json = get_parameters_json(mdata, metadata_df, split=split)
        save_preprocessed(
            outdir, train_mdata, test_mdata, mdata, parameters_json
        )
    return f"Done preprocessing for {dataset_name}"


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