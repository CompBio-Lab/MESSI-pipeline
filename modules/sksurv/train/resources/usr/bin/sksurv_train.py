#!/usr/bin/env python

"""
Train a scikit-survival model on the train fold of a MuData split.
Output is a fitted model (joblib) on the train portion, plus the test MuData
passed downstream — same contract as sklearn_train.py of the classification
method.

Usage:
  sksurv_train.py [options]

Options:
  -h --help                   Show this message
  --fold_path=FOLD_PATH       Directory containing one split (train/test h5mu)
  --label=LABEL               Label of dataset and fold iteration [default: empty]
  --model_name=MOD            Survival model to run: coxnet | rsf | gbm [default: coxnet]
"""

from docopt import docopt
import joblib

from load_tr_te import load_tr_te
from combine_mdata2df_survival import combine_mdata2df_survival
from load_survival_model_class import load_survival_model_class


def train_model(train_data, model_name):
    """Fit a survival model on a train-fold MuData. Returns the fitted pipeline."""
    X_df, mod_names = None, None
    merged_df, mod_names = combine_mdata2df_survival(train_data)
    X_df = merged_df.drop(columns=["time", "status"])
    y = combine_mdata2df_survival(train_data, concat=False)[2]
    builder = load_survival_model_class(model_name)
    model = builder(X_df, y)
    # store training-fold follow-up so prediction clips S(t) horizons correctly
    model._t_min_train = float(y["time"].min())
    model._t_max_train = float(y["time"].max())
    print(f"\n[{model_name}] fitted on {X_df.shape[0]} samples x {X_df.shape[1]} features")
    return model


def main(fold_path, label, model_name):
    train_data, test_data = load_tr_te(fold_path)
    model = train_model(train_data, model_name)
    model_file = f"{label}-{model_name}-model.pkl"
    joblib.dump(model, model_file)
    test_file = f"{label}-test_data.h5mu"
    test_data.write(test_file)
    print(f"Saved {model_file} and {test_file}")
    return model


if __name__ == "__main__":
    args = docopt(__doc__)
    main(
        fold_path=args["--fold_path"],
        label=args["--label"],
        model_name=args["--model_name"],
    )
