#!/usr/bin/env python

"""
This is a sklearn prediction script, loads torch like models and make predictions
Output a summary table with test probability in it.

Usage:
  sklearn_predict.py [options]

Options:
  -h --help                   Show this message
  --model_path=MODEL          Path to trained model on specific fold [default: empty]
  --test_path=TEST_PATH       Path that contains the input for testing [default: empty]
  --label=LABEL               Label of dataset and fold iteration [default: empty]
  --method_name=METHOD_NAME   Method name ran [default: sklearn]
"""

# TODO: The docopt help message above can be better described or reformatted

from docopt import docopt
import joblib
import pickle
import pandas as pd

# Custom import
from generate_result_table import generate_result_table

# Main entrance of the testing script
def main(model_path, test_path, label, method_name):
  # Load model
  model = joblib.load(model_path)
  # Load test mudata
  with open(test_path, 'rb') as tf:
      test_data = pickle.load(tf)
  # Partion the mudata to x df and y df (which contains response and other metadata)
  test_X_df, test_y_df = mudata2df(test_data)
  # Get predicted probabilities
  predicted_df = pd.DataFrame(model.predict_proba(test_X_df), columns=model.classes_)
  # Retrieve the class equals to 1 only (no string required)
  predicted = predicted_df[[1]].to_numpy().ravel()
  result_table = generate_result_table(predicted=predicted, meta_df=test_y_df, method_name=method_name, label=label)
  # Write the result table to csv
  result_file = f"{label}-result.csv"
  result_table.to_csv(result_file, index=False, header=True)
  return result_table

# Execute it here
if __name__ == '__main__':
  # Parse docopt
  args = docopt(__doc__)
  # Execute the main function
  main(
    model_path=args['--mode_path'], 
    test_path=args['--test_path'], 
    label=args['--label'],
    method_name=args['--method_name']
  )