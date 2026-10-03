#!/usr/bin/env python
"""
This script is used to calculate survival metrics from merged out-of-fold (OOF)
results of all compared methods. Each row is one sample predicted while its fold
was the test set, with columns:

  method_name, dataset, fold   identifiers
  time, status                 observed follow-up time and event indicator (1 = event)
  lp                           risk score (higher = higher risk, e.g. Cox linear predictor)
  surv_<t>                     predicted survival probability S(t) at horizon t

Metrics are computed for each fold (training set = the other folds of the same
method + dataset, used for the IPCW censoring weights) and then summarized as
mean / sd across folds (`<metric>_mean`, `<metric>_std`). Probability-based
metrics are also computed on the pooled OOF predictions (`<metric>_pooled`).
The output is one row per method + dataset. C-index on `lp` is NOT pooled because risk scores from different fold
models are on different scales and should not be ranked against each other.
Instead, `c_harrell_s<t>` / `c_uno_s<t>` use 1 - S(t) at --c_horizon as the risk
score, which is a probability and therefore comparable across fold models.

`ipa` (index of prediction accuracy) = 1 - IBS / IBS of a null model that gives
everyone the Kaplan-Meier curve of the training set. 0 = no better than the null
model, so unlike the raw IBS it is comparable across datasets.

Author: Tony Liang

Usage:
  calculate_survival_metrics.py [options]

Options:
  --result_path=RES_PATH    Path to the merged result table [default: empty]
  --out_path=OUT_PATH       Path of the output summary table [default: metrics_summary.csv]
  --round_digit=DIGITS      Number of digits to round metrics [default: 3]
  --c_horizon=T             Horizon t of the 1 - S(t) based C-index [default: 730]
"""

# Import libraries
import re

from docopt import docopt
import pandas as pd
import numpy as np
from sksurv.util import Surv
from sksurv.nonparametric import kaplan_meier_estimator
from sksurv.metrics import (
  concordance_index_censored, concordance_index_ipcw,
  cumulative_dynamic_auc, brier_score, integrated_brier_score
)


ID_COLS = ['method_name', 'dataset', 'fold']


def get_horizons(df):
    """Parse evaluation horizons from the `surv_<t>` column names."""
    cols = [c for c in df.columns if re.fullmatch(r'surv_\d+(\.\d+)?', c)]
    cols = sorted(cols, key=lambda c: float(c.split('_')[1]))
    return cols, np.array([float(c.split('_')[1]) for c in cols])


def safe(fun, *args, **kwargs):
    """Run a metric, return NaN (with a message) if it is not computable."""
    try:
        return fun(*args, **kwargs)
    except ValueError as e:
        print(f"  skipped {fun.__name__}: {e}")
        return None



# Helper to calculate metrics of one evaluation (one fold, or pooled)
def calculate_metrics(train, test, surv_cols, horizons, c_horizon, use_lp=True):
    """
    Arguments:

    train       Rows used to estimate the censoring distribution for IPCW
                (the other folds; for pooled evaluation, all rows)
 ng `surv_cols`
    c_horizon   Horizon t whose 1 - S(t) is used as a fold-comparable risk score
    use_lp      Whether to compute C-indices from `lp`
    """
    y_train = Surv.from_arrays(event=train['status'].astype(bool), time=train['time'])
    # IPCW needs the censoring KM of train at each test time, which sksurv cannot
    # extrapolate past the last train time. Test rows after it are still at risk at
    # every evaluated time (< au)
    y_test = Surv.from_arrays(event=test['status'].astype(bool),
                              time=test['time'].clip(upper=train['time'].max()))

    metrics = {'n': len(test), 'n_events': int(test['status'].sum())}
    c_s = f's{c_horizon:g}'
    for name in ['c_harrell', 'c_uno', f'c_harrell_{c_s}', f'c_uno_{c_s}']:
        metrics[name] = np.nan
    for t in horizons:
        metrics[f'auc_{t:g}'] = np.nan
    for t in horizons:
        metrics[f'brier_{t:g}'] = np.nan
    metrics['mean_auc'] = np.nan
    for name in ['ibs', 'ibs_null', 'ipa']:
        metrics[name] = np.nan
    # S(t) is NaN after the last training event of the fold model (no information)
    surv_all = test[surv_cols].to_numpy()
    predicted = ~np.isnan(surv_all).any(axis=0)
    if not predicted.all():
        print(f"  skipped horizons without S(t) prediction: {horizons[~predicted]}")
    # IPCW metrics only work inside the follow-up range of both train and test
    valid = predicted & (horizons >= test['time'].min()) \
        & (horizons < test['time'].max()) & (horizons < train['time'].max())
    times = horizons[valid]
    surv = surv_all[:, valid]
    tau = times.max() if len(times) else None

     # Discrimination of the overall risk score: `lp` (within one fold model only)
    # and 1 - S(t) at c_horizon (comparable across fold models, so also pooled)
    risk_scores = {}
    if c_horizon in horizons[predicted]:
        risk_scores[f'_{c_s}'] = 1 - test[f'surv_{c_horizon:g}'].to_numpy()
    else:
        print(f"  skipped C-index on 1 - S({c_horizon:g}): no S(t) prediction")
    if use_lp:
        risk_scores = {'': test['lp'].to_numpy(), **risk_scores}
    for suffix, risk in risk_scores.items():
        res = safe(concordance_index_censored,
                   test['status'].astype(bool), test['time'], risk)
        if res is not None:
            metrics[f'c_harrell{suffix}'] = res[0]
        # Uno's C is truncated at tau to keep the IPCW weights stable
        res = safe(concordance_index_ipcw, y_train, y_test, risk, tau=tau)
        if res is not None:
            metrics[f'c_uno{suffix}'] = res[0]

    if len(times) == 0:
        print("  no valid horizon inside the follow-up range")
        return metrics

    # Time-dependent (cumulative/dynamic) AUC, risk at t is 1 - S(t)
    res = safe(cumulative_dynamic_auc, y_train, y_test, 1 - surv, times)
    if res is not None:
        for t, a in zip(times, res[0]):
            metrics[f'auc_{t:g}'] = a
        metrics['mean_auc'] = res[1]
    # Integrated Brier score over the horizons (needs at least 2)
    if len(times) >= 2:
        res = safe(integrated_brier_score, y_train, y_test, surv, times)
        if res is not None:
            metrics['ibs'] = res
        # Null model: Kaplan-Meier curve of the training set for everyone
        km_t, km_s = kaplan_meier_estimator(train['status'].astype(bool), train['time'])
        s_null = km_s[np.searchsorted(km_t, times, side='right') - 1]
        res = safe(integrated_brier_score, y_train, y_test,
                   np.tile(s_null, (len(test), 1)), times)
        if res is not None:
            metrics['ibs_null'] = res
            metrics['ipa'] = 1 - metrics['ibs'] / res

    return metrics



    # Main entrance of the script
def main(result_path, out_path, round_digit, c_horizon):
    df = pd.read_csv(result_path)
    surv_cols, horizons = get_horizons(df)
    print(f"Horizons found: {horizons}")
    if c_horizon not in horizons:
        raise ValueError(f"--c_horizon={c_horizon:g} is not one of the horizons {horizons}")

    rows = []
    for (method, dataset), group in df.groupby(['method_name', 'dataset']):
        folds = sorted(group['fold'].unique())
        print(f"\n{method} / {dataset}: {len(folds)} folds, {len(group)} samples")
        # Keep only horizons predicted in every fold, so per-fold metrics (e.g. IBS
        # range, Uno's tau) are comparable to each other and to the pooled ones
        common = group[surv_cols].notna().all(axis=0).to_numpy()
        if not common.all():
            print(f" horizons dropped (no S(t) in some fold): {horizons[~common]}")
            group = group.drop(columns=np.array(surv_cols)[~common])
        g_cols, g_horizons = list(np.array(surv_cols)[common]), horizons[common]
        if c_horizon not in g_horizons:
            print(f" --c_horizon={c_horizon:g} dropped, no 1 - S(t) C-index")
        # Per fold: censoring distribution from the training part of that fold
        for fold in folds:
            print(f" {fold}")
            test = group[group['fold'] == fold]
            train = group[group['fold'] != fold]
            rows.append({'method_name': method, 'dataset': dataset, 'fold': fold,
                         **calculate_metrics(train, test, g_cols, g_horizons, c_horizon)})
        # Pooled OOF predictions, probability-based metrics only
        print(" pooled")
        rows.append({'method_name': method, 'dataset': dataset, 'fold': 'pooled',
                     **calculate_metrics(group, group, g_cols, g_horizons, c_horizon,
                                         use_lp=False)})
    # Same columns for every group, even if some horizons were dropped
    per_fold = pd.DataFrame(rows)
    c_s = f's{c_horizon:g}'
    per_fold = per_fold.reindex(columns=ID_COLS + [
        'n', 'n_events', 'c_harrell', 'c_uno', f'c_harrell_{c_s}', f'c_uno_{c_s}',
        *[f'auc_{t:g}' for t in horizons], *[f'brier_{t:g}' for t in horizons],
        'mean_auc', 'ibs', 'ibs_null', 'ipa'])
    metric_cols = [c for c in per_fold.columns if c not in ID_COLS + ['n', 'n_events']]
    # Mean and sd across folds, plus the pooled values
    is_pooled = per_fold['fold'] == 'pooled'
    grouped = per_fold[~is_pooled].groupby(['method_name', 'dataset'])
    summary = grouped[metric_cols].agg(['mean', 'std'])
    summary.columns = [f'{m}_{s}' for m, s in summary.columns]
    summary.insert(0, 'n_folds', grouped.size())
    pooled = per_fold[is_pooled].set_index(['method_name', 'dataset'])
    summary.insert(1, 'n', pooled['n'])
    summary.insert(2, 'n_events', pooled['n_events'])
    pooled = pooled[metric_cols]
    pooled = pooled.dropna(axis=1, how='all').add_suffix('_pooled')
    summary = summary.join(pooled).reset_index()

    # =====================================================
    # Write out the summary dataframe
    print(f"\nSaving metrics to '{out_path}'")
    summary.round(round_digit).to_csv(out_path, index=False)

    return summary



# Execute the fun here
if __name__ == '__main__':
    # Parse docopt
    args = docopt(__doc__)
    # Execute runner
    main(
        result_path=args['--result_path'],
        out_path=args['--out_path'],
        round_digit=int(args['--round_digit']),
        c_horizon=float(args['--c_horizon'])
    )
