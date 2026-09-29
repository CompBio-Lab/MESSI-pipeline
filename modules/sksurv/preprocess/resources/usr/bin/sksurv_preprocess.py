#!/usr/bin/env python

"""
Preprocess survival MuData for training: partition the full MuData into
per-fold directories, each containing the train and test h5mu portion,
using pre-computed fold test indices (fold_*.txt). Same contract as
sklearn_preprocess.py of the classification method.

Usage:
  sksurv_preprocess.py [options]

Options:
  -h --help                          Show this message
  --data_path=DATA_PATH              Path to MuData h5mu [default: empty]
  --split_dir=SPLIT_DIR              Path to directory of fold txt files [default: splits]
  --dataset_name=DNAME               Name of the dataset [default: empty]
"""

from docopt import docopt
import os
import mudata

from load_test_splits import load_test_splits
from tr_te_split_mdata import tr_te_split_mdata


def main(mdata_path, split_dir, dataset_name, base_dir="fold", ext="h5mu"):
    mdata = mudata.read(mdata_path)
    # sanity: survival outcome columns must be present
    if not {"time", "status"}.issubset(mdata.obs.columns):
        first_mod = list(mdata.mod.keys())[0]
        if not {"time", "status"}.issubset(mdata[first_mod].obs.columns):
            raise ValueError("MuData obs must contain 'time' and 'status' columns")

    test_splits_df = load_test_splits(split_dir)
    for i, split in enumerate(test_splits_df.index):
        outdir = f"{base_dir}_{i+1}"
        os.makedirs(outdir, exist_ok=True)
        train_file = f"{outdir}/{dataset_name}-train_mu.{ext}"
        test_file = f"{outdir}/{dataset_name}-test_mu.{ext}"
        train_mu, test_mu = tr_te_split_mdata(mdata, splits_df=test_splits_df, split=split)
        train_mu.write_h5mu(train_file)
        test_mu.write_h5mu(test_file)
    return None


if __name__ == "__main__":
    args = docopt(__doc__)
    main(
        mdata_path=args["--data_path"],
        split_dir=args["--split_dir"],
        dataset_name=args["--dataset_name"],
    )
