import re
import pandas as pd

# Use this fun to extract the fold from label of the data by "dataset_name-fold_{i}"
def extract_fold_name(label, pattern="fold_\\d+"):
    matches = re.findall(pattern, label)
    return matches[0]

def generate_result_table(predicted, meta_df, method_name, label, decimals=3):
    # First read in the previous metadata table
    df = meta_df.copy()
    # Append the method name and predicted probabilities
    df["phat"] = np.round(predicted, decimals)
    df["method_name"] = method_name
    df["fold"] = extract_fold_name(label)
    # reorder it to desired format
    desired_order = ["sample_name", "y", "phat", "method_name", "dataset", "fold"]
    df = df[desired_order]
    # Sample name as to be always string, sometimes it could come in as integer
    df["sample_name"] = df["sample_name"].astype('string')
    return df