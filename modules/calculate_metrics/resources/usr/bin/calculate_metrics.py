#!/usr/bin/env python
"""
This script is used to calculate metrics from merged results of all compared methods
given their method name ,dataset, true response label (binary) and predicted probability
of the positive class.

Author: Tony Liang

Usage:
  calculate_metrics.py [options]
  
Options:
  --result_path=RES_PATH    Path to the merged result table [default: empty]
  --threshold=THRESHOLD     Threshold to classify phat as of class [default: 0.5]
"""

# Import libraries
from docopt import docopt
import pandas as pd
import numpy as np
from sklearn.metrics import (
  accuracy_score, balanced_accuracy_score,
  precision_score, average_precision_score,
  recall_score,  roc_auc_score,
  f1_score,
  log_loss, matthews_corrcoef
)

# Helper to apply for grouping of data to calculate metrics
def calculate_metrics(group, threshold, average='binary', round_digit=3):
    """
    Arguments:

    group       Grouped dataframe of specifc method + dataset combination
    threshold   Value of determining to classify as positive(1) or negative(0) class
    average     Method of average on computing metrics
    round_digit Number of digits to round metrics
    """
    # Extract convenient vars
    y_true = group['y']
    phat = group['phat']
    y_pred = np.where(phat >= threshold, 1, 0)
    # Initialize dict for metrics
    metrics = {
        'roc_auc': 0.0,
        'pr_auc': 0.0,
        'f1_score': 0.0,
        'log_loss': 0.0,
        'matthews_corrcoef': 0.0,
        'accuracy': 0.0,
        'balanced_accuracy': 0.0,
        'precision': 0.0,
        'recall': 0.0,

    }

    try:
        # Check if both classes are present in the current group
        if len(set(y_true)) > 1:  # More than one unique value in y_true
            # AUC requires predicted probability (phat) not y_pred
            metrics['roc_auc']                = roc_auc_score(y_true, phat)
            # Same thing with precision-recall auc
            metrics['pr_auc']                 = average_precision_score(y_true, phat)
            # Rest could use the predicted class (y_pred) to calculate metrics
            metrics['f1_score']               = f1_score(y_true, y_pred, average=average)
            metrics['log_loss']               = log_loss(y_true, phat)
            metrics['matthews_corrcoef']      = matthews_corrcoef(y_true, y_pred)
            metrics['accuracy']               = accuracy_score(y_true, y_pred)
            metrics['balanced_accuracy']      = balanced_accuracy_score(y_true, y_pred)
            metrics['precision']              = precision_score(y_true, y_pred, average=average)
            metrics['recall']                 = recall_score(y_true, y_pred, average=average)


        else:
            raise ValueError("Only one class present")
    
    except ValueError as e:
        print(f"Error processing group {group.name}: {e}")
        print(f"The predictions are: {y_pred}")
        print(f"The true labels are: {y_true}")
    
    # Round results and return as pd.Series
    return pd.Series({k: round(v, round_digit) for k, v in metrics.items()})


# Main entrance of the script
def main(result_path, threshold):
  df = pd.read_csv(result_path)
  # Apply the custom metric calculation fun for each method, dataset comb, fold
  grouping_cols = ['method_name', 'dataset'] # Should not be using fold specific due to big variation
  #grouping_cols = ['method_name', 'dataset', 'fold']
  metrics_df = df.groupby(grouping_cols).apply(
    # The custom fun
    calculate_metrics,
    threshold=threshold
    #include_groups=False
  ).reset_index()
  # =====================================================
  # Write out this output metric dataframe
  metric_file = "metrics.csv"
  print(f"\nSaving metrics to '{metric_file}'")
  metrics_df.to_csv(metric_file, index=False)

  return metrics_df

# Execute the fun here
if __name__ == '__main__':
  # Parse docopt
  args = docopt(__doc__)
  # Execute runner
  # TODO: Remove the replace na val as its not doing anything here
  main(
    result_path=args['--result_path'] , threshold=float(args['--threshold'])
  )
