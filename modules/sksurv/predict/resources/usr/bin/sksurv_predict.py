#!/usr/bin/env python

"""
Predict per-observation survival results with a trained scikit-survival model.
Outputs a result table with one row per test observation: risk score (lp) and
predicted survival probabilities S(t) at fixed horizons (days).

Usage:
  sksurv_predict.py [options]

Options:
  -h --help                   Show this message
  --model_path=MODEL          Path to trained model on specific fold [default: empty]
  --test_path=TEST_PATH       Path to the test MuData h5mu [default: empty]
  --label=LABEL               Label of dataset and fold iteration [default: empty]
  --method_name=METHOD_NAME   Method name ran [default: sksurv]
"""

from docopt import docopt
import joblib
import numpy as np
import pandas as pd

from combine_mdata2df_survival import combine_mdata2df_survival
from generate_result_table_survival import generate_result_table
from load_survival_model_class import SURV_HORIZONS


def survival_at_horizons(model, X_df, horizons, t_min_train, t_max_train):
    """Evaluate predicted S(t) at fixed horizons, clipped to train follow-up."""
    sfs = model.predict_survival_function(X_df)
    out = np.zeros((len(X_df), len(horizons)))
    for j, h in enumerate(horizons):
        if h < t_min_train:
            out[:, j] = 1.0          # before any observed follow-up: S = 1
        else:
            h_eff = min(h, t_max_train)
            out[:, j] = [float(sf(h_eff)) for sf in sfs]
    # defensive sanitization: Breslow baselines can diverge numerically
    return np.clip(np.nan_to_num(out, nan=0.0, posinf=1.0, neginf=0.0), 0.0, 1.0)


def predict_model(model, test_data, horizons=None):
    """Return (lp, surv_matrix, meta_df) for a test-fold MuData."""
    horizons = horizons or SURV_HORIZONS
    X_df, meta_df, _ = combine_mdata2df_survival(test_data, concat=False)
    lp = model.predict(X_df)
    # training-fold follow-up range stored at fit time; fall back to test range
    t_max_train = getattr(model, "_t_max_train", None) or float(meta_df["time"].max())
    t_min_train = getattr(model, "_t_min_train", None) or float(meta_df["time"].min())
    surv = survival_at_horizons(model, X_df, horizons, t_min_train, t_max_train)
    return lp, surv, meta_df


def main(model_path, test_path, label, method_name):
    model = joblib.load(model_path)
    import mudata
    test_data = mudata.read(test_path)
    lp, surv, meta_df = predict_model(model, test_data)
    result_table = generate_result_table(
        lp=lp, surv=surv, meta_df=meta_df, method_name=method_name, label=label
    )
    result_file = f"{label}-{method_name}-result.csv"
    result_table.to_csv(result_file, index=False, header=True)
    print(f"Wrote {result_file}")
    return result_table


if __name__ == "__main__":
    args = docopt(__doc__)
    main(
        model_path=args["--model_path"],
        test_path=args["--test_path"],
        label=args["--label"],
        method_name=args["--method_name"],
    )
