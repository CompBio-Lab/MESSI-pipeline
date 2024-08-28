import pandas as pd
from sklearn.model_selection import train_test_split

def get_idxs(mdata, random_state, block_num, test_size, axis_col="sample_name"):
    # Get the modality keys
    mod_keys = list(mdata.mod.keys())
    # Use first block to split as idxs would same across all
    ann = mdata.mod[mod_keys[block_num]]
    # Split the block to X and Y component required for the split
    X = ann.to_df().rename_axis(axis_col).reset_index() # This is single "block"
    Y = ann.obs.reset_index(drop=True)
    df = pd.merge(X, Y, on=axis_col)
    # Then need perform the splitting (single)
    train, test = train_test_split(df, test_size=test_size, random_state=random_state,
                                   stratify=df['response'])
    train_idx, test_idx = train.index.to_list(), test.index.to_list()
    return train_idx, test_idx