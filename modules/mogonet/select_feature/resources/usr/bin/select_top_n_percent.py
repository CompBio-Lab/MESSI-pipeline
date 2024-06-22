import pandas as pd
# This select top n percent for each group
# Whereas here handles a per group action
def select_top_n_percent(group, criteria, n_percent):
    group = group.copy()
    group['abs_criteria'] = group[criteria].abs()
    group = group.sort_values(by='abs_criteria', ascending=False)
    top_n = round(n_percent * len(group) / 100)
    return group.head(top_n).drop(columns=['abs_criteria'])