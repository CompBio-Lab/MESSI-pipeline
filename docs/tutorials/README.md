# Flow of methods and instructions


Each method has cross-validation from Nextflow, such that the folds are created priorly, and each mtehod use same folds to ensure same
comparisons carried. And, each fold is being handled parallely with very few times as batch mode (one complete chunk).

So each method would be like this:

1. Preprocess (takes all folds and split the data up), so you would have all folds as independent files now, and each of them could be treated
separately in a process.

2. Train (With option of inner cross-validation), this takes each individual chunk of data from previous preprocessed step and fit fold-specific model on train-portion of the data. Its test-portion would then be outputted to downstream step along with its fitted model

3. Test, this takes in a fold specific fitted model and test portion of data and it would predict based on the labels inside the test portion, lastly it would output a table of summary and metadata info. With strictly this format, order of columns matte

For example, if method was on `diablo`, and on both ROSMAP and Breast TCGA dataset. Values here are just for demonstration purpose.

| sample_name | y | phat | method_name | dataset |
| :-: | :-: | :-: | :-: | :-: |
| patient-1 | 0 | 0.243 | diablo | ROSMAP |
| SR12 | 0 | 0.421 | diablo | TCGA |
| patient-2 | 1 | 0.78 | diablo | ROSMAP |
| SR21 | 1 | 0.85 | diablo | TCGA |
| patient-3 | 1 | 0.42 | diablo | ROSMAP |
| SR31 | 1 | 0.37 | diablo | TCGA |
| patient-4 | 0 | 0.67 | diablo | ROSMAP |
| SR41 | 0 | 0.71 | diablo | TCGA |

Some explantions:

- sample_name: Patient identifier inside the dataset, as if like each row id of a dataframe
- y: The class label, either 1 or 0 in binary classification
- phat:        Predicted proability of y == 1, so P(Y=1)
- method_name: Name of the method ran (DIABLO, MOGONET, ...)
- dataset:     Name of the dataset of study (TCGA, ROSMAP, ...)
