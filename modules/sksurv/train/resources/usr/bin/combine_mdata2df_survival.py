import mudata
import numpy as np
import pandas as pd


# Structured array dtype expected by scikit-survival
SURV_Y_DTYPE = [("status", "?"), ("time", "<f8")]


def get_survival_obs(mdata, time_col="time", status_col="status"):
    """Return the obs dataframe carrying time/status.

    Prefers MuData-level obs (MoMIX h5mu convention), falls back to the first
    modality's obs (some conversions store metadata per modality).
    """
    if {time_col, status_col}.issubset(mdata.obs.columns):
        return mdata.obs
    first_mod = list(mdata.mod.keys())[0]
    mod_obs = mdata[first_mod].obs
    if not {time_col, status_col}.issubset(mod_obs.columns):
        raise ValueError(
            f"Neither MuData obs nor first modality obs contain "
            f"'{time_col}' and '{status_col}'"
        )
    return mod_obs


def to_surv_y(time, status):
    """Build the scikit-survival structured array (status bool, time float)."""
    y = np.empty(len(time), dtype=SURV_Y_DTYPE)
    y["time"] = np.asarray(time, dtype=float)
    y["status"] = np.asarray(status).astype(bool)
    return y


def combine_mdata2df_survival(mdata, concat=True, time_col="time", status_col="status"):
    """Extract X features and survival outcome from a MuData.

    X_df: column-concatenated feature dataframe, each modality prefixed
          (e.g. 'exp_UMOD|7369'), same convention as the classification method.
    meta: dataframe with sample_name, time, status (index aligned with X_df).
    y:    scikit-survival structured array.

    With concat=True also return the merged dataframe (X + time + status).
    """
    mod_names = list(mdata.mod.keys())
    X_df = pd.concat(
        [mdata[k].to_df().add_prefix(f"{k}_") for k in mod_names], axis=1
    )
    obs = get_survival_obs(mdata, time_col, status_col)

    sample_name = (
        obs["sample_name"].astype(str)
        if "sample_name" in obs.columns
        else pd.Series(obs.index.astype(str), index=obs.index)
    )
    meta = pd.DataFrame(
        {
            "sample_name": sample_name,
            "time": pd.to_numeric(obs[time_col], errors="raise").astype(float),
            "status": pd.to_numeric(obs[status_col], errors="raise").astype(int),
        },
        index=X_df.index,
    )
    # sanity: event coding must be 0/1
    assert meta["status"].isin([0, 1]).all(), "status must be 0 (censored) / 1 (event)"
    assert meta["time"].notna().all(), "time contains missing values"

    y = to_surv_y(meta["time"], meta["status"])

    if not concat:
        return X_df, meta, y
    merged_df = pd.concat([X_df, meta[["time", "status"]]], axis=1)
    return merged_df, mod_names
