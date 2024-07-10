#!/usr/bin/env python

"""
This is script to train model from {{ method|lower }} method. Output is a fitted model on the previously
processed train MuData, and previously processed test MuData from specific fold.

Usage:
  {{ method_lower }}_train.py [options]

Options:
  -h --help                   Show this message
  --fold_path=FOLD_PATH       Directory containing one split directory of relevant input [default: empty] 
  --label=LABEL               Label of dataset and fold iteration [default: empty]
"""

from docopt import docopt
import pandas as pd
import pickle

# =============================================================================
# Little utilities to use here
# =============================================================================


# See here: https://stackoverflow.com/questions/70584201/i-dont-understand-why-set-seed-is-needed-with-torch-and-tensorflow-import
# def set_seed(seed: int):
#     """
#     Helper function for reproducible behavior to set the seed in ``random``, ``numpy``, ``torch`` and/or ``tf`` (if
#     installed).

#     Args:
#         seed (:obj:`int`): The seed to set.
#     """
#     random.seed(seed)
#     np.random.seed(seed)
#     if is_torch_available():
#         torch.manual_seed(seed)
#         torch.cuda.manual_seed_all(seed)
        # ^^ safe to call this function even if cuda is not available

# TODO: Implement here
def train(fold_path):
  return NotImplementedError

# TODO: Implement here
def get_test_data(fold_path):
  return NotImplementedError

# from upstream process
def main(fold_path, label):
  # TODO: Implement your logic of training model
  model = train(fold_path)
  test_data = get_test_data(fold_path)

  # Parse label and choose output file to write
  model_file = f"{label}-model.pt"
  with open(model_file, 'wb') as mf:
    pickle.dump(model, mf)
  # Also write the test input to file so that it is pass to downstream
  test_file = f"{label}-test_input.pkl"
  with open(test_file, 'wb') as tf:
    pickle.dump(test_data, tf)

  # And writing the metadata file for downstream
  return model
# Execute it here
if __name__ == '__main__':
  # Parse docopt
  args = docopt(__doc__)
  main(
    fold_path = args["--fold_path"],
    label     = args["--label"]
  )

