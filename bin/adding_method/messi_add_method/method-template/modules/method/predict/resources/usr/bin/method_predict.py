#!/usr/bin/env python

"""
This is a {{ method|lower }} prediction script, loads torch like models and make predictions
Output a summary table with test probability in it.

Usage:
  {{ method|lower }}_predict.py [options]

Options:
  -h --help                   Show this message
  --model_path=MODEL          Path to trained model on specific fold [default: empty]
  --test_path=TEST_PATH       Path that contains the input for testing [default: empty]
  --metadata_path=META        Path to the additional metadata like sample name, response [default: empty]
  --label=LABEL               Label of dataset and fold iteration [default: empty]
  --method_name=METHOD_NAME   Method name ran [default: {{ method|lower }} ]
"""

# TODO: The docopt help message above can be better described or reformatted

from docopt import docopt
import pickle
import pandas as pd

def predict_test(model, test_data):
    # TODO: You could have this function in this script or place it elsewhere
    # Takes the model and predict on the testdata
    # testdata should be in N x p_i format, where N is total number of observations, 
    # p_i is number of features in i views of omics
    # Should return a n x 1 dimensional vector of probabilities in positive class of binary classification
    raise NotImplementedError
    

def generate_result_table(predicted, metadata_path, method_name, decimals=3):
    # First read in the previous metadata table
    df = pd.read_csv(metadata_path)
    # Append the method name and predicted probabilities
    df["phat"] = predicted
    df["method_name"] = method_name
    # reorder it to desired format
    desired_order = ["sample_name", "y", "phat", "method_name", "dataset"]
    df = df[desired_order]
    # Sample name as to be always string, sometimes it could come in as integer
    df["sample_name"] = df["sample_name"].astype('string')
    # Round phat
    df['phat'] = df['phat'].apply(lambda x: round(x, decimals))
    return df

# TODO: Implement this main function to be taking a fold-specific model fit on train data
#       and evaluate/predict on the fold-specific test data
def main(model_path, test_path, metadata_path, label, method_name):
  # Load model
  with open(model_path, 'rb') as mf:
      model = pickle.load(mf)
  # Load test input
  with open(test_path, 'rb') as tf:
      test_data = pickle.load(tf)
  # TODO: Need to implement predict_test and generate_result_table accordingly
  predicted = predict_test(model=model, test_data=test_data)
  result_table = generate_result_table(predicted=predicted, metadata_path=metadata_path, method_name=method_name)
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
    metadata_path=args['--metadata_path'],
    label=args['--label'],
    method_name=args['--method_name']
  )