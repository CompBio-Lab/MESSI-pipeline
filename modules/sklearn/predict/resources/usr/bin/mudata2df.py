import mudata
import pandas as pd

def mudata2df(mdata):
    # Takes in a mudata and extract X and y components
    # Get the Xs as a dataframe of combining all modality together columnwise
    mod_names = list(mdata.mod.keys())
    X_df = pd.concat( [mdata[k].to_df() for k in mod_names], axis=1 )
    # Also extract the observation df
    y_df = mdata[mod_names[0]].obs[["response"]]
    # Should contain response column and is of string yes or no
    assert y_df["response"].isin(['yes', 'no']).all(), "Column contains values other than 'yes' or 'no'"
    # Converting to numeric binary
    y_df["response"] = y_df["response"].map({"no": 0, "yes": 1})
    return X_df, y_df