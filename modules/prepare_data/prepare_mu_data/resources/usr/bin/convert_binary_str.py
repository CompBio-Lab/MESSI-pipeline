# MuData likes it to have i of N x pi AnnData 
# So rownames are the patient names
# while columns are just omics specific features
import pandas as pd

# Convert the column to binary and categorical object of yes and no
def convert_binary_str(col):
    # Params to use
    str_labels = ["yes", "no"]
    isCategorical = isinstance(col.dtype, pd.api.types.CategoricalDtype)
    matched_entries = set(col.unique()) == set(str_labels)
    if isCategorical & matched_entries:
        return col
    # rest assume is 1 or 0
    else:
        print("Convert to string binary")
        col = ["yes" if str(x) == "1" else "no" for x in  col]    
    return col