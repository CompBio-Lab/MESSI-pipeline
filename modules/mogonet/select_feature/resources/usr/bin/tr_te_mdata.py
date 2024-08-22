import numpy as np
def tr_te_mdata(mdata, train_idx, test_idx, meta):
    # Get train and test copy
    train_mu, test_mu = mdata[train_idx].copy(), mdata[test_idx].copy()
    # Add this metadata for downstream access
    cols_interest = ["sample_name", "y"]
    # TODO: this rename is kinda risky, since it could skip if did not match naming
    test_meta = meta.reset_index(drop=True).rename(columns={"sample_names": "sample_name",
                                                           "response": "y"})
    test_meta = test_meta[cols_interest].loc[test_idx]
    ## Get the response from obs aswell
    # TODO: need to check this bit below
    y = meta["response"].values
    if (isinstance(y[0], str)):
        bin = lambda y: 1 if y == "yes" else 0
        y = np.vectorize(bin)(y)
    train_y, test_y = y[train_idx], y[test_idx]
    # Return as output joined together
    return (train_mu, train_y), (test_mu, test_y), test_meta
