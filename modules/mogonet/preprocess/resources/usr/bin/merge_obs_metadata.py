def merge_obs_metadata(df):
    # Check common cols
    split_cols = df.columns.str.split(':', expand=True)
    unique_cols = split_cols.get_level_values(1).unique()
    # Drop those duplicated values on columns of each block
    df = df.T.drop_duplicates().T
    # Rename cols
    df.columns = unique_cols
    return df