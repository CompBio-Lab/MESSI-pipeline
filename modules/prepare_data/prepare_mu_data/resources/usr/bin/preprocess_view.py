import pandas as pd


from near_zero_var import near_zero_var


def safe_filter(X, keep, step, min_cols=2):
    """
    X     : pandas DataFrame or numpy array (n_samples x n_features)
    keep  : boolean mask (length = n_features)
    step  : string, name of filtering step
    """

    kept = int(keep.sum())
    total = len(keep)
    if kept < min_cols:
        print(f"[SKIP] {step}: {kept}/{total} features")
        return X  # return unfiltered X
    print(f"[OK]   {step}: {kept}/{total} features")
    # IMPORTANT: keep 2D shape
    if hasattr(X, "loc"):   # pandas
        return X.loc[:, keep]
    else:                   # numpy
        return X[:, keep]

# Helper function to calculate the threshold to use for filtering feature
def calculate_threshold(variances, threshold_type='mean', percentile=0.10):
    """
    Calculates the threshold for feature selection based on variance.

    Parameters:
    - variances (pd.Series): Series of variances for each feature.
    - threshold_type (str): Type of threshold to calculate ('mean', 'median', 'percentile').
    - percentile (float): The percentile to use if 'percentile' is selected (default is 0.10).

    Returns:
    - float: The calculated threshold value.
    """
    if threshold_type == 'mean':
        return variances.mean()
    elif threshold_type == 'median':
        return variances.median()
    elif threshold_type == 'percentile':
        if percentile < 0 or percentile > 1:
            raise ValueError("Percentile must be between 0 and 1.")
        return variances.quantile(percentile)
    else:
        raise ValueError("Invalid threshold_type. Choose from 'mean', 'median', or 'percentile'.")

# DEPRECATED: this version can fail at edge cases, e.g., when there are only two unique values and one of them is NA
# def compute_freq_ratio(data):
#     data = data.dropna()
#     if len(data.unique()) == len(data):
#         return 1
#     elif len(data.unique()) == 1:
#         return 0
#     else:
#         value_counts = data.value_counts()
#         return value_counts.max() / value_counts.iloc[1] if len(value_counts) > 1 else value_counts.max()


# DEPRECATED: this version can fail at edge cases
# def near_zero_var(df, freqCut = 95/5, uniqueCut=10):
#     # Calculate the number of unique values per column
#     lunique = df.apply(lambda data: len(data.dropna().unique()), axis=0)

#     # Calculate percentUnique
#     percent_unique = 100 * lunique / len(df)

#     # Identify zero variance columns
#     zero_var = (lunique == 1) | df.apply(lambda data: data.isna().all(), axis=0)

#     # Calculate freqRatio for each column
#     freq_ratio = df.apply(compute_freq_ratio, axis=0)

#     # Identify the positions where the conditions hold
#     positions = (freq_ratio > freqCut) & (percent_unique <= uniqueCut) | zero_var
#     positions = positions[positions].index.tolist()

#     # Prepare the output
#     out = {}
#     out['Position'] = positions
#     out['Metrics'] = pd.DataFrame({
#         'freqRatio': freq_ratio,
#         'percentUnique': percent_unique
#     })

#     # Filter the metrics based on positions
#     out['Metrics'] = out['Metrics'].loc[positions]
#     return out['Metrics']



# TODO: the last three arguments are not used for now
def preprocess_view(df, var_threshold=0.16, replace_na_val=0, scale=False, filter_low_var=False):
    df_copy = df.copy()
    # 1. First remove NAs in features (columns here)
    df_copy = df_copy.dropna(axis=1)
    # 2. Remove features with variance less than mean of all variances
    # Calculate variance for each column
    if not filter_low_var:
        df_reduced = df_copy
    else:
        variances = df_copy.var()
        # Use mean of the variances as threshold to keep
        threshold = calculate_threshold(variances, threshold_type="mean")
        # These are the relevant columns to keep
        relv_feats = variances >= threshold
        df_reduced = safe_filter(df_copy,relv_feats,step="Variance filter",min_cols=2)
        # Then filter it out
        # NOTE: In python, it uses AnnData and MuData, so dont need to worry about prefixing
        # view_name into the feature name
        #df_reduced = df_copy.loc[:, relv_feats]
	# And apply the nearZeroVar fun (implemented based on mixOmics)
        # Then, check those features that have at least 50% of its values not being zero
        # And, remove those that have 70% of zero
        zero_var_feats = near_zero_var(df_reduced, freq_cut = 70/5, unique_cut = 50)["Metrics"].index.tolist()
        df_reduced = df_reduced.drop(columns=zero_var_feats)
    return df_reduced
