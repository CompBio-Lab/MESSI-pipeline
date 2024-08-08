#!/usr/bin/env python

"""
This is a Mogonet prediction script, loads torch like models and make predictions
Output a summary table with test probability in it

Usage:
  predict_mogonet.py [options]

Options:
  -h --help                   Show this message
  --model=MODEL               Trained model on specific fold [default: empty]
  --test_path=TEST_PATH       Path that contains the input for testing [default: empty]
  --metadata_path=META        Path to the metadata of test set [default: empty]
  --label=LABEL               Label of dataset and fold iteration [default: empty]
  --method_name=METHOD_NAME   Method name ran [default: mogonet]
"""

from docopt import docopt
from mogonet.test_mogonet import test_mogonet
from mogonet.utils import load_model_dict
from generate_result_table import generate_result_table
import os
import pickle
import pandas as pd


def main(model, test_path, metadata_path, label, method_name):
  # This the main logic to execute
  # First load the model and test input
  model_dict = load_model_dict(model)
  with open(test_path, 'rb') as f:
    test_input = pickle.load(f)
  
  # Then get the test probabilities
  phat = test_mogonet(model_dict=model_dict, test_input=test_input)
  # Now wrap it to make summary table of the following format:
  # sample_name, y, phat, method_name, dataset
  result_table = generate_result_table(metadata_path=metadata_path, phat=phat, method_name=method_name, label=label)
  # Write to csv
  result_file = f"{label}-result.csv"
  result_table.to_csv(result_file, index=False, header=True)
  return result_table

# Execute it here
if __name__ == '__main__':
  # Parse docopt
  args = docopt(__doc__)
  # Execute the main function
  main(model=args['--model'], 
  test_path=args['--test_path'], 
  metadata_path=args['--metadata_path'],
  label=args['--label'],
  method_name=args['--method_name']
  )