import pandas as pd
from sklearn.feature_selection import VarianceThreshold
from sklearn.preprocessing import StandardScaler

def preprocess_view(df, var_threshold=0.16, replace_na_val=0, scale=True):
    # Make copies of convenient objects
    df_copy = df.copy()
    sample_name = df_copy.index
    # First drop NAs column wise
    df_reduced = df_copy.dropna(axis=1)
    # Second apply scaling to standard normal
    if scale:
        scaler = StandardScaler()
        df_reduced = pd.DataFrame(scaler.fit_transform(df_reduced), columns=df_reduced.columns)
    # Lastly remove near zero variance
    try:
        selector = VarianceThreshold(threshold=var_threshold)
        # Fit the selector to the data and transform the data
        df_reduced = selector.fit_transform(df_reduced)
    except Exception as e:
        print(e)
        print("\nTrying a new var threshold instead by choosing mean of variance of each column")
        new_var_threshold = df_copy.var().mean()
        selector = VarianceThreshold(threshold=new_var_threshold)
        # Fit the selector to the data and transform the data
        df_reduced = selector.fit_transform(df_reduced)
    # Convert the transformed data back into a DataFrame
    # Get the columns that were kept
    columns_kept = df.columns[selector.get_support()]
    df_reduced = pd.DataFrame(df_reduced, columns=columns_kept, index=sample_name)
    return df_reduced