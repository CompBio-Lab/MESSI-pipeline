#!/usr/bin/env python
"""
This is the script to split Mudata, it is designed to
return single splits within a fold.

Author: Tony Liang

Usage:
  split_tr_te.py [options] MDATA

Arguments:
  MDATA                    path to find MuData format

Options:
  --split_type=SPLIT_TYPE   Type of split to perform            [default: sgkf]
  --num_splits=NUM_SPLITS   Number of splits to generate		    [default: 10]
  --seed=SEED               Random number seed to reproduce     [default: 329]
  --output_dir=OUT_DIR      Output folder to write fold ids txt [default: splits]
  --split_txt_name=SNAME    Name of individual fold txt file    [default: fold]
"""

from docopt import docopt
from sklearn.model_selection import StratifiedKFold
from anndata import AnnData
import pandas as pd
import numpy as np
import mudata
import os
# Cli arguments from parsing docstring
args = docopt(__doc__)
print(args)

# Main function to execute
# Split train test by stratified
def main(mdata_path, split_type, k, random_state, output_dir, split_txt_name, identifier_col="sample_name"):
  if (split_type == "logo"):
    raise NotImplementedError("Leave One Group Out not implemented yet")
  if (split_type == "sgkf"):
      k = int(k)
  # Some input parameters -----------------------------------------------------
  random_state = int(random_state)
  mdata = mudata.read(mdata_path) # Load the MuData from path
  #print(mdata)
  mod_keys = list(mdata.mod.keys())
  # TODO: Depending on a different block, this could have effect
  # 			on affecting the splits
  # Use first block to split as idxs would same across all
  block_ann = mdata.mod[mod_keys[0]]
  # Split the block to X and Y component required for the split
  X = block_ann.to_df() # This is single "block"
  Y = block_ann.obs[["response"]]
  groups = block_ann.obs[[identifier_col]].values
  # Reshift indices to 0 based
  assert X.shape[0] == Y.shape[0]
  # Splitting goes here ------------------------------------------------------
  # Built the kfold and store to dict
  # TODO:: use StratifiedGroupKFold
  # TODO: check for distribution of the Y response, the minimum number of obs in levels to be >= k
  # Proceed with warning and outputs that
  # use default sample name as the group
  skf = StratifiedKFold(n_splits=k , shuffle=True, random_state=random_state)
  # Preallocate space to save those indices belonging to test set
  fold_test_idxs = {}
  # requires 1st to be X numerical and y be the response
  # So use the first block of it
  for i, (tr_idx, te_idx) in enumerate(skf.split(X,Y)):
    fold_label = f"{split_txt_name}_{i+1}"
    # Manually shift index by 1 for each one
    #te_idx = [idx + 1 for idx in te_idx]
    fold_test_idxs[fold_label] = te_idx
    # Write these test indices to file
    current_fold = f"{output_dir}/{fold_label}.txt"
    with open(current_fold, "w") as file:
      print(f"Written {current_fold} to file")
      file.write('\n'.join(str(x) for x in te_idx))
  return fold_test_idxs
# Execute it
main(
  mdata_path         	= args['MDATA'],
  split_type          = args['--split_type'],     # type of split
	k										= args['--num_splits'],     # number of splits
  random_state  			= args['--seed'],           # Default it 329 instead
	output_dir					= args['--output_dir'],     # Default to splits
  split_txt_name      = args['--split_txt_name']  # Default to fold
  )