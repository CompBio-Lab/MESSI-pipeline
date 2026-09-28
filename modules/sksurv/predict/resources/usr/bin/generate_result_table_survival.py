import re
import numpy as np
import pandas as pd


def extract_fold_name(label, pattern="fold_\\d+"):
    matches = re.findall(pattern, label)
    return matches[0]


def extract_dataset_name(label):
    return label.rsplit("-", 1)[0]


def generate_result_table(lp, surv, meta_df, method_name, label,
                          horizons=(365, 548, 730, 1095, 1461, 1826), decimals=3):
    """Build the per-observation prediction table for survival methods.

    lp    : risk score per observation (higher = riskier)
    surv  : (n_obs, len(horizons)) matrix of predicted S(t)
    meta_df: dataframe with sample_name, time, status
    """
    df = meta_df.copy()
    df["lp"] = np.round(np.asarray(lp, dtype=float), decimals)
    surv = np.asarray(surv, dtype=float)
    for j, h in enumerate(horizons):
        df[f"surv_{h}"] = np.round(surv[:, j], decimals)
    df["method_name"] = method_name
    df["fold"] = extract_fold_name(label)
    df["dataset"] = extract_dataset_name(label)
    desired_order = (
        ["sample_name", "lp"]
        + [f"surv_{h}" for h in horizons]
        + ["time", "status", "method_name", "dataset", "fold"]
    )
    df = df[desired_order]
    df["sample_name"] = df["sample_name"].astype("string")
    return df
