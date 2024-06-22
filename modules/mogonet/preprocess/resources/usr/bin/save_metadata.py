import os
import pandas as pd
  
# Helper to save metadata of current test set
def save_metadata(metadata, split, outdir):
    name = f"fold_{split}-metadata-test.csv"
    path = os.path.join(outdir, name)
    try:
      metadata.to_csv(path, header=True, index=False)
      print(f"Saved metadata to {path}")
    except Exception as e:
      print(f"Failed to save metadata because of: {e}")
    return path
