import numpy as np
import pandas as pd


# This implementation closely follows the logic of R's nearZeroVar function, 
# including handling of unique value counting and frequency ratio calculation to match R's behavior. 
# It also includes handling for all-missing columns and preserves column names when input is a DataFrame.
# Otherwise, it wouldnt return the same results as R's nearZeroVar, which is important for consistency in feature selection.

def _normalize_input(x):
    """Convert input to a 2D numpy array, extracting column names if available."""
    col_names = None
    if isinstance(x, pd.DataFrame):
        col_names = x.columns.tolist()
        x = x.values
    if x.ndim == 1:
        x = x.reshape(-1, 1)
    return col_names, x


def _count_unique(values):
    """Count unique values using repr() to match R's unique() behavior."""
    return len(set(repr(v) for v in values))


def _compute_freq_ratio(values):
    """Ratio of most common to second most common value frequency.

    Uses .15g formatting to match R's table() -> as.character() coercion.
    """
    str_values = pd.Series([f"{v:.15g}" for v in values])
    counts = str_values.value_counts().sort_values(ascending=False)

    if len(counts) <= 1:
        return 1.0 if len(counts) == len(values) else 0.0
    return counts.iloc[0] / counts.iloc[1]


def _all_missing_mask(x):
    """Boolean mask for columns where every value is NA."""
    return np.array([np.all(pd.isna(x[:, j])) for j in range(x.shape[1])])

def near_zero_var(x, freq_cut=95/5, unique_cut=10):
    col_names, x = _normalize_input(x)
    n_rows, n_cols = x.shape

    freq_ratios = np.zeros(n_cols)
    unique_counts = np.zeros(n_cols, dtype=int)

    for j in range(n_cols):
        col = x[:, j]
        non_missing = col[~pd.isna(col)]
        unique_counts[j] = _count_unique(non_missing)
        freq_ratios[j] = _compute_freq_ratio(non_missing)

    percent_unique = 100 * unique_counts / n_rows
    is_zero_var = (unique_counts == 1) | _all_missing_mask(x)
    is_near_zero_var = (freq_ratios > freq_cut) & (percent_unique <= unique_cut)

    positions = np.where(is_near_zero_var | is_zero_var)[0]
    labels = [col_names[i] for i in positions] if col_names else positions.tolist()

    metrics = pd.DataFrame({
        "freqRatio": freq_ratios[positions],
        "percentUnique": percent_unique[positions],
    }, index=labels)

    return {"Position": positions.tolist(), "Metrics": metrics}
