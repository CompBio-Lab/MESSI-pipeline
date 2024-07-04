# Flow of methods and instructions


Each method has cross-validation from Nextflow, such that the folds are created priorly, and each mtehod use same folds to ensure same comparisons carried. And, each fold is being handled parallely with very few times as batch mode (one complete chunk).

To see detailed step by step instructions, you could see this [guide](adding_r-based_method/adding_r-based_method.md)


Here, we breakdown the high level steps of each method flow:

1. Preprocess (takes all folds and split the data up), so you would have all folds as independent files (txt) now, then they're treated as single batch job to make the actual splitting and saved them into smaller MAE or MuData.

  - For detailed explanation for R method see this [guide](preprocessing/R/preprocesing.md)


2. Train (With option of inner cross-validation for available method), this takes each individual chunk of data from previous preprocessed step and fit fold-specific model on train-portion of the data. Its test-portion would then be outputted to downstream step along with its fitted model.

3. Test, this takes in a fold specific fitted model  and test portion of data from previous step 2 and it would predict based on the labels inside the test portion, lastly it would output a table of summary and metadata info like true label, sample name, method name, etc.

> [!NOTE]  
> It should contain these columns in the table of summary: **sample_name**, **y**, **phat**, **method_name**, **dataset**

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

- sample_name:  Patient identifier inside the dataset, as if like each row id of a dataframe
- y:            The class label, either 1 or 0 in binary classification
- phat:         Predicted proability of y == 1, so P(Y=1)
- method_name:  Name of the method ran (DIABLO, MOGONET, ...)
- dataset:      Name of the dataset of study (TCGA, ROSMAP, ...)
