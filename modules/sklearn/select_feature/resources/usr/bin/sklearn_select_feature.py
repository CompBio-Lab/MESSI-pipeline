#!/usr/bin/env python

"""
This is a script for sklearn to perform feature selection on full portion of 
data (from MuData).

Usage:
  sklearn_select_feature.py [options]

Options:
  -h --help                   Show this message
  --data_path=DATA_PATH       Path that contains full portion of MuData [default: empty]
  --dataset_name=DNAME        Label of the dataset [default: empty]
  --n_percent=N_PER           N percent of features selected from each view [default: 10]
  --method_name=METHOD_NAME   Name of the method [default: sklearn]
"""

# TODO: You could improve the docstring above and add more arguments if desired
from docopt import docopt
import pandas as pd
import mudata
import os
import copy

# TODO: Implement this
def run_cv(mdata):
    return NotImplementedError

# TODO: Implement this
def get_weights(final_model):
    return NotImplementedError

# TODO: Implement this
def fit_model(mdata, **hyperparams):
    return NotImplementedError


# This select top n percent for each group
# Whereas here handles a per group action
def select_top_n_percent(group, criteria, n_percent):
    group = group.copy()
    group['abs_criteria'] = group[criteria].abs()
    group = group.sort_values(by='abs_criteria', ascending=False)
    top_n = round(n_percent * len(group) / 100)
    return group.head(top_n).drop(columns=['abs_criteria'])

def get_selected_features(final_model, n_percent, method, dataset_name):
    selected_df = get_weights(final_model) # TODO: Need to implement this
    # Select top N percent of features from each view (omics)
    # TODO: Need to rename 'omics_name' to be the column that contains info of what omics a feature corresponding to
    feats_df = selected_df.groupby('omics_name').apply(
      select_top_n_percent, criteria="coef_column_name", n_percent=n_percent
    ).reset_index(drop=True)
    
    feats_df["method"] = method
    feats_df["dataset_name"] = dataset_name
    # Lastly select the right columns out, need to match namings
    out_columns = ["feature", "view", "method", "dataset_name"]
    feats_df = feats_df[out_columns]
    return feats_df



# This is the main entrance of the script
# TODO: You need to re-implement the main logic
# 1. Perform some kind of cv to find hyperparameters
# 2. Use those found optimal hyperparams to fit final model
# 3. Then select top weights from the final model
# 4. Take top H percent of each view (omic) features from the dataset input
def main(mu_path, dataset_name, n_percent, method, block_num=0):
    """
    Parameters
    ----------

    mu_path:        Path to the h5mu that contains multiomics data
    dataset_name:   Name of the dataset
    n_percent:      Top N percent of features to select
    method:         Name of the method
    block_num:      N-th block of all blocks to use to stratify from, default takes 0 (1st)
    test_size:      Size of the test data
      
    """

    # --------------------
    # IMPLEMENTATION
    # --------------------
    raw_mdata = mudata.read(mu_path)
    # Use a copy here to avoid mixing up stuff
    mdata = raw_mdata.copy()
    #view_list = [*mdata.mod]
    # Get top n from mdata
    # TODO: Every python method are relied on different networks
    # So could vary a lot

    cv_model = run_cv(mdata)
    # TODO: Need to add hyperparameters from cv_model to this final model
    final_model = fit_model(mdata, ...)
    # TODO: The output dataframe need to have the following structure:
    feats_df = get_selected_features(final_model, n_percent, method, dataset_name) # TODO: Need to get feats from final model
    
    filename = f"{method}-{dataset_name}_features_selected.csv"
    # And write it to file
    feats_df.to_csv(filename, index=False)
    return(feats_df)


# Execute it here
if __name__ == '__main__':
  # Parse docopt
  args = docopt(__doc__)
  # Execute the main function
  main(mu_path=args['--data_path'], 
  dataset_name=args['--dataset_name'],
  n_percent=int(args['--n_percent']),
  method=args['--method_name']
  )