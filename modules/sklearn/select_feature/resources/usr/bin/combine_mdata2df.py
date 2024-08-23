import mudata
import pandas as pd


# Combine all modalities in mdata to single dataframe
def combine_mdata2df(mdata):
    # first mod
    first_mod = list(mdata.mod.keys())[0]
    y_df = mdata[first_mod].obs[["response"]]
    # Create an empty list to hold DataFrames
    dfs = []
    # Iterate over each modality
    for mod in mdata.mod.keys():
    # Get the DataFrame for the modality and add the prefix of view_feat_i
      mod_df = mdata[mod].to_df()
      mod_df.columns = [f"{mod}_{col}" for col in mod_df.columns]
      dfs.append(mod_df)
    # Concatenate all modality DataFrames
    X_df = pd.concat(dfs, axis=1)
    # Merge all DataFrames together
    merged_df = pd.concat([X_df, y_df], axis=1)
    return merged_df
