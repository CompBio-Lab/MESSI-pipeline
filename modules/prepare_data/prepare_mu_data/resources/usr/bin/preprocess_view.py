import pandas as pd
from sklearn.feature_selection import VarianceThreshold
from sklearn.preprocessing import StandardScaler

def preprocess_view(df, var_threshold=0.16, replace_na_val=0, scale=True):
    df_copy = df.copy()
    sample_names = df_copy.index
    # Create the VarianceThreshold object
    # Sometimes matrix could too small variance in each
    try:
        selector = VarianceThreshold(threshold=var_threshold)
        # Fit the selector to the data and transform the data
        df_reduced = selector.fit_transform(df_copy)
    except Exception as e:
        print(e)
        print("\nTrying a new var threshold instead by choosing mean of variance of each column")
        # TODO: this not top great now
        # might need a different option to remove zero vars features
        var_threshold = df_copy.var().mean()
        selector = VarianceThreshold(threshold=var_threshold)
        # Fit the selector to the data and transform the data
        df_reduced = selector.fit_transform(df_copy)
    # Convert the transformed data back into a DataFrame
    # Get the columns that were kept
    columns_kept = df.columns[selector.get_support()]
    df_reduced = pd.DataFrame(df_reduced, columns=columns_kept, index=sample_names)
    # replace the nas with 0
    df_reduced = df_reduced.fillna(replace_na_val)
    # Now also center and scale the data
    # Create a StandardScaler instance
    if not scale:
        return df_reduced
    scaler = StandardScaler()
    # Fit the scaler to the DataFrame and transform it
    df_reduced = pd.DataFrame(scaler.fit_transform(df_reduced), columns=df_reduced.columns)
    return df_reduced