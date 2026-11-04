# {{ method }}: worked example, ridge-penalised logistic regression on all views
# joined together, with scikit-learn.
#
# Test without Nextflow:  python bin/adding_method/add_method.py check {{ method }}

import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

# Recorded in selected_hyperparameters.json as "fixed".
HYPERPARAMETERS = {"penalty": "l2", "C": 1.0}


def fit(X_train, y_train, **kwargs):
    """Input: X_train, dict of samples x features DataFrames; y_train, 0/1 array.
    Output: any picklable object, here a dict with what the other two functions need.
    """
    X = pd.concat(X_train.values(), axis=1)
    pipeline = make_pipeline(
        StandardScaler(),
        LogisticRegression(penalty=HYPERPARAMETERS["penalty"], C=HYPERPARAMETERS["C"], max_iter=1000),
    )
    pipeline.fit(X.values, y_train)
    return {
        "pipeline": pipeline,
        "features": list(X.columns),
        "views": [view for view, frame in X_train.items() for _ in frame.columns],
    }


def predict_proba(model, X_test):
    """Input: the object from fit; X_test, dict of DataFrames.
    Output: 1-D array of P(class = 1), one per row of X_test.
    """
    X = pd.concat(X_test.values(), axis=1)
    return model["pipeline"].predict_proba(X.values)[:, 1]


def feature_weights(model):
    """Input: the object from fit.
    Output: DataFrame with columns feature, view, coef.
    """
    coef = model["pipeline"].named_steps["logisticregression"].coef_[0]
    return pd.DataFrame({"feature": model["features"], "view": model["views"], "coef": coef})
