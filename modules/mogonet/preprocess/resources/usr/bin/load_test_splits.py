import numpy as np
import pandas as pd
import os
import glob

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