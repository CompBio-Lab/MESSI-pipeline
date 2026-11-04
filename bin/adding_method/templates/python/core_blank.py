# {{ method }}: THE ONE FILE YOU EDIT.
#
# Fill in the three functions below. The MESSI wrappers do everything else: they
# load the data and the fold split, call these functions, save the model and write
# the result, feature and hyperparameter files. You write no file I/O here.
#
# Test without Nextflow:  python bin/adding_method/add_method.py check {{ method }}
# Packages: import them at the top of this file. They must exist in the method's
# container: python bin/adding_method/add_method.py check-image {{ method }}

# Optional: settings to record in selected_hyperparameters.json, for example
# HYPERPARAMETERS = {"C": 1.0}. A plain value is recorded as "fixed". To say otherwise
# use {"C": {"value": 1.0, "treatment": "tuned"}}, where treatment is one of tuned,
# fixed, default, data-derived.
HYPERPARAMETERS = {}


def fit(X_train, y_train, **kwargs):
    """Train the model.

    Input
      X_train  dict with one pandas DataFrame per omics view.
               Rows are samples, columns are features, for example
               {"mrna": <80 x 200 DataFrame>, "mirna": <80 x 120 DataFrame>}.
               The index holds sample names, in the same order in every view.
               The columns hold feature names. Use .values for a numpy matrix.
      y_train  1-D numpy integer array of 0/1 with one label per row.
               1 is the positive class.
      kwargs   Includes seed, an integer. random.seed and numpy.random.seed have
               already been called with it.
    Output
      Any picklable Python object. It is saved with pickle and passed to the other
      two functions.

    Minimal example:
      X = pd.concat(X_train.values(), axis=1)
      return {
          "weights": (X[y_train == 1].mean() - X[y_train == 0].mean()).values,
          "features": list(X.columns),
          "views": [view for view, df in X_train.items() for _ in df.columns],
      }
    """
    raise NotImplementedError("fit() is not implemented yet. Fill it in: {{ core_path }}")


def predict_proba(model, X_test):
    """Score new samples.

    Input
      model   The object fit() returned.
      X_test  dict of DataFrames like X_train: same views and features, other samples.
    Output
      1-D numeric numpy array of probabilities of class 1, in [0, 1], with no NaN.
      One value per row of X_test, in the same order.
      Return one column only: scikit-learn's predict_proba(X)[:, 1], not the whole
      two-column matrix.

    Minimal example:
      X = pd.concat(X_test.values(), axis=1)
      return 1 / (1 + np.exp(-X.values @ model["weights"]))
    """
    raise NotImplementedError("predict_proba() is not implemented yet. Fill it in: {{ core_path }}")


def feature_weights(model):
    """How much each feature counts.

    Input
      model  The object fit() returned, fitted on all samples of the dataset.
    Output
      pandas DataFrame with one row per feature and exactly these columns:
        feature  str, the name exactly as in X_train[view].columns
        view     str, one of the keys of X_train
        coef     float and finite, the signed weight

    Minimal example:
      return pd.DataFrame({"feature": model["features"], "view": model["views"], "coef": model["weights"]})
    """
    raise NotImplementedError("feature_weights() is not implemented yet. Fill it in: {{ core_path }}")
