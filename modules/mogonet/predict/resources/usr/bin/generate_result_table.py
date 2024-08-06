import pandas as pd
import re

# Use this fun to extract the fold from label of the data by "dataset_name-fold_{i}"
def extract_fold_name(label, pattern="fold_\\d+"):
    matches = re.findall(pattern, label)
    return matches[0]

# Helper to make this result table 
def generate_result_table(metadata_path, phat, method_name, label, decimals=3):
    # First read in the previous metadata table
    df = pd.read_csv(metadata_path)
    # Append the method name, phat, and which test fold was from
    df["phat"] = phat
    df["method_name"] = method_name
    df["fold"] = extract_fold_name(label)
    # reorder it to desired format
    desired_order = ["sample_name", "y", "phat", "method_name", "dataset", "fold"]
    df = df[desired_order]
    # Sample name as to be always string, sometimes it could come in as integer
    df["sample_name"] = df["sample_name"].astype('string')
    # Round phat
    df['phat'] = df['phat'].apply(lambda x: round(x, decimals))
    return df
