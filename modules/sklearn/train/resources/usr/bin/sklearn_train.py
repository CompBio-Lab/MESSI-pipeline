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
from mudata2df import mudata2df


# Train data is MuData
# model_name is name of classifier to use from sklearn
# See main function of available options
def train(train_data, model_name):
    # Transform the mudata into X and y for sklearn
    # X_df contains all count data from the views
    # y_df contains response and other metadata information
    X_df, y_df = mudata2df(train_data)
    # Dynamically load classifier class
    classifier_class, params = load_classifier_class(model_name)
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
    test_file = f"{label}-test_data.pkl"
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

