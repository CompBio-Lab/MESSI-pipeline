import mudata
import pandas as pd
import numpy as np


def mudata2df(mdata):
    # Takes in a mudata and extract X and y components
    # Get the Xs as a dataframe of combining all modality together columnwise
    mod_names = list(mdata.mod.keys())
    # We also add the modality in front of every feature just like "epigenomics_some_feature_name"
    X_df = pd.concat( [mdata[k].to_df().add_prefix(f"{k}_") for k in mod_names], axis=1 )
    # Also extract the observation df
    y_df = mdata[mod_names[0]].obs[["response"]]
    # Should contain response column and is of string yes or no
    assert y_df["response"].isin(['yes', 'no']).all(), "Column contains values other than 'yes' or 'no'"
    # Converting to numeric binary
    y_df.loc[:, "response"] = np.where(y_df["response"] == "yes", 1, 0)
    return X_df, y_df
