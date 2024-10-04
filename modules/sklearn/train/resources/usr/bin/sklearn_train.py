#!/usr/bin/env python

"""
This is script to train model from sklearn method. Output is a fitted model on the previously
processed train MuData, and previously processed test MuData from specific fold.

Usage:
  sklearn_train.py [options]

Options:
  -h --help                   Show this message
  --fold_path=FOLD_PATH       Directory containing one split directory of relevant input [default: empty] 
  --label=LABEL               Label of dataset and fold iteration [default: empty]
  --model_name=MOD            Name of the classifier to run from sklearn [default: empty]
"""

from docopt import docopt
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

import mudata
import pandas as pd
import joblib
import pickle

# Custom imports
from load_classifier_class import load_classifier_class
from load_tr_te import load_tr_te
from combine_mdata2df import combine_mdata2df


# Train data is MuData
# model_name is name of classifier to use from sklearn
# See main function of available options
def train(train_data, model_name, target_col="response"):
    # Convert the mdata to merged dataframe column wise
    merged_df = combine_mdata2df(train_data)
    # Transform the mudata into X and y for sklearn
    # X_df contains all count data from the views
    # y_df contains response
    X_df, y_df = merged_df.drop(columns=[target_col]), merged_df[[target_col]]
    # Dynamically load classifier class
    # The third is params_dist which is for cv tuning, so discard it
    classifier_class, params, _ = load_classifier_class(model_name)
    # Unpack those params for the classifier, and instantiate it
    clf = classifier_class(**params)
    print("\n", clf)
    # Tells to first apply standard scaling, then the model
    clf = make_pipeline(StandardScaler(), clf)
    # Fitting model
    clf.fit(X_df, y_df["response"])
    return clf


# from upstream process
def main(fold_path, label, model_name):
    # Load data first from fold_path
    train_data, test_data = load_tr_te(fold_path)
    # Train sklearn classifier available options are:
    # 'AdaBoost', 'Decision Tree', 'Gaussian Process', 'Linear SVM', 'Naive Bayes',
    # 'Nearest Neighbors', 'Neural Net', 'QDA', 'RBF SVM', 'Random Forest'
    # Case sensitive
    model = train(train_data, model_name=model_name)
    # Parse to more machine readable label 
    model_label = model_name.lower().replace(" ", "_")
    # Parse label and choose output file to write
    model_file = f"{label}-{model_label}-model.pkl"
    # TODO: Decide to use pickle or joblib to write the trained model?
    joblib.dump(model, model_file)
    # Also write the test mudata to file so that it is passed to downstream
    test_file = f"{label}-test_data.h5mu"
    test_data.write(test_file)

    # And writing the metadata file for downstream
    return model

# Execute it here
if __name__ == '__main__':
  # Parse docopt
  args = docopt(__doc__)
  main(
    fold_path  = args["--fold_path"],
    label      = args["--label"],
    model_name = args["--model_name"]
  )

