import mudata
import pandas as pd

def tr_te_split_mdata(mdata, splits_df, split):
    # Given the original mdata and a splits_df containing indices of test folds, partion
    # the original mudata to have a train and test copy
    test_idx = splits_df.loc[split].iloc[0]
    # Get the rest idxs except those in current split, sorted
    train_idx = sorted(splits_df[splits_df.index != split].test_indices.explode().tolist())
    # Get train and test copy
    train_mu, test_mu = mdata[train_idx].copy(), mdata[test_idx].copy()
    return train_mu, test_mu