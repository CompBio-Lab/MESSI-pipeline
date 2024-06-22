import pandas as pd

# Helper to make this result table 
def generate_result_table(metadata_path, phat, method_name, decimals=3):
    # First read in the previous metadata table
    df = pd.read_csv(metadata_path)
    # Append the method name and phat
    df["phat"] = phat
    df["method_name"] = method_name
    # reorder it to desired format
    desired_order = ["sample_name", "y", "phat", "method_name", "dataset"]
    df = df[desired_order]
    # Sample name as to be always string, sometimes it could come in as integer
    df["sample_name"] = df["sample_name"].astype('string')
    # Round phat
    df['phat'] = df['phat'].apply(lambda x: round(x, decimals))
    return df
