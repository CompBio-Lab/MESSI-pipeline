#!/usr/bin/env python

"""
This is a script for mogonet to perform feature selection on full portion of 
data (from MuData).

Usage:
  mogonet_select_features.py [options]

Options:
  -h --help               Show this message
  --mu_path=MU_PATH       Path that contains full portion of MuData [default: empty]
  --dataset_name=DNAME    Label of the dataset [default: empty]
  --n_percent=N_PER       N percent of features selected [default: 10]
  --reps=REPS             Repetitions to run "to mimic cv" [default: 5]
"""

from docopt import docopt
import pandas as pd
import mudata
import os
import copy
# Custom functions import
from prepare_mogonet_single_split import prepare_mogonet_feat_select
from feature_importance import  cal_feat_imp, summarize_imp_feat


def get_view_list(data_folder):
    # First list all *_featname.csv in current data folder
    pattern = "_featname.csv"
    csvs = [csv for csv in os.listdir(data_folder) if pattern in csv]
    # Remove the pattern, so left should be block name
    view_list = [csv.replace(pattern, "") for csv in csvs]
    return view_list

# Function to set a seed
def seed_everything(seed: int):
    import random, os
    import numpy as np
    import torch
    
    random.seed(seed)
    os.environ['PYTHONHASHSEED'] = str(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed(seed)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = True

# TODO: The feat importance is always 0?
# and make sure to have topn to be big number
# like 10% of datasize
def main(mu_path, dataset_name, n_percent, random_state=123, block_num=0, test_size=0.25, reps=5, num_class=2):
    """
    Parameters
    ----------

    mu_path:        path to the h5mu that contains multiomics data
    dataset_name:   name of the dataset
    n_percent:      top N percent of features to select
    random_state:   seed to reproduce result
    block_num:      n-th block of all blocks to use to stratify from?
    test_size:      size of the test data
    reps:           repetition to run the select feature
      
    """


    # ---------------
    # PARAMS
    # ---------------
    method = "mogonet"
    he_base_dim = 100
    adj_parameter = 5 # This has to be small, otherwise fails at somewhere when calculating adj matrix for tensors
    # --------------------
    # IMPLEMENTATION
    # --------------------
    raw_mdata = mudata.read(mu_path)
    # Use a copy here to avoid mixing up stuff
    mdata = raw_mdata.copy()
    view_list = [*mdata.mod]
    # Get top n from mdata
    # TODO: ...
    # It still needs to be splitted as specified format of mogonet

    # Allocate empty list to store result of different rep
    featimp_list_list = []
    for rep in range(reps):
        # Use a different random state to mimic "new splitting" for different repetitions
        new_random_state = random_state + rep
        seed_everything(new_random_state)


        data_folder = prepare_mogonet_feat_select(mdata, dataset_name, random_state=new_random_state, 
                                        block_num=block_num, test_size=test_size)
        print(f"Seed number: '{new_random_state}' for '{data_folder}'")
        # =====================================================================================
        # This is the list of feature importance in single rep
        # he_base_dim is the dim of each he per omic, more like hidden layers?
        # adj_parameter needs to be tuned?
        featimp_list = cal_feat_imp(data_folder=data_folder, view_list=view_list, 
                                    num_class=num_class, he_base_dim = he_base_dim, adj_parameter = adj_parameter)
        # Add to the earlier allocated list
        featimp_list_list.append(copy.deepcopy(featimp_list))
    # Then run a summary on this list of lists
    feats_df = summarize_imp_feat(featimp_list_list=featimp_list_list, view_list=view_list,
                                  dataset_name=dataset_name, n_percent=n_percent)
    filename = f"{method}-{dataset_name}_features_selected.csv"
    # And write it to file
    feats_df.to_csv(filename, index=False)
    return(feats_df)


# Execute it here
if __name__ == '__main__':
  # Parse docopt
  args = docopt(__doc__)
  # Execute the main function
  main(mu_path=args['--mu_path'], 
  dataset_name=args['--dataset_name'],
  n_percent=int(args['--n_percent']),
  reps=int(args['--reps'])
  )
