#!/usr/bin/env python

"""
This is a Mogonet script with cli arguments support
Change this script for your use and write more useful doc here

Usage:
  run_mogonet.py [options]

Options:
  -h --help                   Show this message
  --fold_path=FOLD_PATH       Directory containing one split directory of relevant input [default: None] 
  --label=LABEL               Label of dataset and fold iteration [default: empty]
  --seed=SEED                 Seed number to reproduce it [default: 0]
"""

from docopt import docopt
from mogonet.train_mogonet import train_mogonet
from mogonet.utils import save_model_dict
import os
import glob
import pandas as pd
import pickle

# =============================================================================
# Little utilities to use here
# =============================================================================
def get_view_list(data_folder):
    # First list all *_featname.csv in current data folder
    pattern = "_featname.csv"
    csvs = [csv for csv in os.listdir(data_folder) if pattern in csv]
    # Remove the pattern, so left should be block name
    view_list = [csv.replace(pattern, "") for csv in csvs]
    return view_list

def write_metadata(data_folder, label):
    dataset_name  = label.split('-fold')[0]
    metadata_file = glob.glob(os.path.join(data_folder, "*meta*"))[0]
    output_file = f"{dataset_name}-{os.path.basename(metadata_file)}"
    # Then read in and add the dataset_name in
    meta_df = pd.read_csv(metadata_file)
    meta_df["dataset"] = dataset_name
    meta_df.to_csv(output_file, header=True, index=False)
    print(f"Wrote to {output_file}")
    return meta_df


# See here: https://stackoverflow.com/questions/70584201/i-dont-understand-why-set-seed-is-needed-with-torch-and-tensorflow-import
def set_seed(seed: int):
    """
    Helper function for reproducible behavior to set the seed in ``random``, ``numpy``, ``torch`` and/or ``tf`` (if
    installed).

    Args:
        seed (:obj:`int`): The seed to set.
    """
    random.seed(seed)
    np.random.seed(seed)
    if is_torch_available():
        torch.manual_seed(seed)
        torch.cuda.manual_seed_all(seed)
        # ^^ safe to call this function even if cuda is not available
# Train a model network from mogonet, assuming having those right inputs 
# from upstream process
def main(
    data_folder, 
    label,
    view_list=None,
    num_class=2,
    lr_e_pretrain=1e-3,
    lr_e=5e-4,
    lr_c=1e-3,
    num_epoch_pretrain=50,
    num_epoch=200,
    test_interval=50,
    adj_parameter=8
    ):
  # Do something with mogonet here
  # ===========================================================================
  #                         Handle parameter checks
  # ===========================================================================
  # Generate the view list by finding all *_featname.csv of each block
  if view_list is None:
    view_list = get_view_list(data_folder=data_folder)
  # ===========================================================================
  # Main executing goes here
  # ===========================================================================
  model_dict, test_input = train_mogonet(
        data_folder         = data_folder, 
        view_list           = view_list, 
        num_class           = num_class, 
        lr_e_pretrain       = lr_e_pretrain, 
        lr_e                = lr_e, 
        lr_c                = lr_c, 
        num_epoch_pretrain  = num_epoch_pretrain, 
        num_epoch           = num_epoch, 
        adj_parameter       = adj_parameter
  )
  # Parse label and choose output file to write
  model_file = f"{label}-model.pt"
  # Then save the trained model to disk
  save_model_dict(model_dict, model_file)
  # Also write the test input to file so that it is pass to downstream
  test_file = f"{label}-test_input.pkl"
  with open(test_file, 'wb') as f:
    pickle.dump(test_input, f)
  print(f"\nSaved input for testing at: {test_file}")
  write_metadata(data_folder, label)
  # And writing the metadata file for downstream
  
  
  return model_dict
# Execute it here
if __name__ == '__main__':
  # Parse docopt
  args = docopt(__doc__)
  # Execute runner
  #grid_params = {}
  #SEED = int(args["--seed"])
  #if SEED == 0:
  #  raise "Did not provide a seed number to begin"
  # Set seed for reproducibility
  #set_seed(int(args["--seed"]))
  # Execute the main function
  main(
    data_folder = args["--fold_path"],
    label       = args["--label"]
  )

# Runner for Mogonet
# def mogonet_runner(data_path, view_list=None, lr_e_pretrain = 1e-3, lr_e = 5e-4, lr_c = 1e-3, 
#                    num_epoch_pretrain = 500, num_epoch = 500):
#     """
#     Main runner of the MOGONET algorithm, takes several hyperparameters, and does train-test split of the data_folder,
#     where transforms the data to epochs for GNN. <---- EDIT here
    
#     """


    
#     #if data_folder.__contains__('ROSMAP'):
#     #    num_class = 2
#     #if data_folder.__contains__('BRCA'):
#     #    num_class = 5
#     if data_path.__contains__('GSE'):
#         num_class = 2
#     #else:
#     #    return("Wrong dataset input")

#     # NOTE this is not robusted tested, requires extra function to split train test
#     # and into many files per train/test, and their labels, feature names
#     # Look here: https://github.com/tonyliang19/MOGONET/tree/main/BRCA
#     train_test(data_path, view_list, num_class,
#                lr_e_pretrain, lr_e, lr_c, 
#                num_epoch_pretrain, num_epoch)             
#     return 0
