import pandas as pd

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

# TODO: the last three arguments are not used for now
def preprocess_view(df, var_threshold=0.16, replace_na_val=0, scale=False):
    df_copy = df.copy()
    # 1. First remove NAs in features (columns here)
    df_copy = df_copy.dropna(axis=1)
    # 2. Remove features with variance less than mean of all variances
    # Calculate variance for each column
    variances = df_copy.var()
    # Use mean of the variances as threshold to keep
    threshold = calculate_threshold(variances, threshold_type="mean")
    # These are the relevant columns to keep
    relv_feats = variances >= threshold
    # Then filter it out
    # NOTE: In python, it uses AnnData and MuData, so dont need to worry about prefixing
    # view_name into the feature name
    df_reduced = df_copy.loc[:, relv_feats]
    
    return df_reduced