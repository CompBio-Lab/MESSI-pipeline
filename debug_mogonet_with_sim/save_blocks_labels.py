import os
import numpy as np

# Helper to save labels as binary
def save_label(y, outdir, opt=None):
    if opt is None:
        return "No option provided for saving label, abort"
    base = "labels"
    if opt == "train":
        ext = "tr.csv"
    if opt == "test":
        ext = "te.csv"
    name = f"{base}_{ext}"
    p = os.path.join(outdir, name)
    np.savetxt(p, y, fmt="%i")
    return None
  
# Helper to save blocks    
def save_blocks(mdata, outdir, opt=None):
    if opt is None:
        return "No option provided for saving blocks, abort"
    if opt == "train":
        ext = "tr.csv"
    if opt == "test":
        ext = "te.csv"
    for b, ann in mdata.mod.items():
        # Paths to write these to file
        bp = f"{b.lower()}_{ext}"
        block_path = os.path.join(outdir, bp)
        fp = f"{b.lower()}_featname.csv"
        feat_path = os.path.join(outdir, fp)
        featnames = ann.var
        block = ann.to_df()
        # Write to files
        block.to_csv(block_path, header=False, index=False)
        featnames.to_csv(feat_path, header=False, index=False)

def save_blocks_labels(train, test, outdir):
    # For each train and test we need to split the blocks out and their labels
    # The input is always comes in X , y combination
    # Unpack values first, and check dims
    train_mu, train_y = train
    assert train_mu.n_obs == train_y.shape[0]
    test_mu, test_y = test
    assert test_mu.n_obs == test_y.shape[0]
    # --------------------------------------
    # save labels
    save_label(train_y, outdir, opt="train")
    save_label(test_y, outdir, opt="test")
    # --------------------------------------
    save_blocks(train_mu, outdir, opt="train")
    save_blocks(test_mu, outdir, opt="test")