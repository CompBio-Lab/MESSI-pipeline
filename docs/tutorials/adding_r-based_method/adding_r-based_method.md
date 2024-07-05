Guide to add a R method
================
Tony Liang
2024-07-03

## Intro

This document ilustrate step by step of adding a multiomics integration
method implemented in `R` into the MESSI-pipeline running on nextflow.

In order to add such method, you need the following steps:

1.  Prepare a dockerfile that describes all relevant software
    dependencies required by a method, with using a templated provided
    [here](../containers/README.md) at `r_method_base_dev.Dockerfile`.
    It provides important dependencies `MultiAssayExperiment`, `here` ,
    and `docopt`.

    **Note**: If your method is too old, which requires older version of
    R, then you might need to create everything from scratch and not use
    the provided template.

2.  Implement a preprocessing script, training script, and testing
    script. The inputs and output are specified down below sections

3.  Declare the inputs/outputs, container used in nextflow scripts

4.  Test it

## Toy Example

We will use logistic regression (LR) as an example to act as a new
method to add into MESSI. First, we need to create such dockerfile that
includes packages that has LR in it, which is alredy in base R accessed
by `stats::glm()`. Just for the sake of demonstration, I included a
snippet of Dockefile.

``` bash
# This is the dockerfile for logistic regression
# 
# This let us use the template docker image as base
# to skip over installation/compilation of important deps
# like docopt, here, and MultiAssayExperiment
FROM tonyliang19/r_method_base_dev

# Then install the stats pkg just for demo purpose
# normally, it is automatically included in baseR
# NOTE: The "" and '' quotation marks are needed
RUN Rscript -e "install.packages('stats')"
```

### Implementing the Nextflow workflow for the method

Create a new `main.nf` under `~/subworkflows/methods/<method_name>/`,
where `<method>_name` is a directory named after the method inteded to
use, and `~` is the root directory of this repository. In this example,
we will named it `logistic_reg`

In here, we created the file named
`~/subworkflows/methods/logistic_reg/main.nf`. This subworkflow handles
the high level logic of data flow through preprocess, train, predict
stesp. We provided a template located at
`~/templates/nxf_scripts/method_subworkflow.nf`:

``` groovy
// Include all relevant modules of a method

// This modulesDir is built in the config file, dont need to worry it
def method_dir = "${modulesDir}/logistic_reg"
// These modules are to be implemented later, uses capital case since convention
include { LOGISTIC_REG_PREPROCESS }   from "${method_dir}/preprocess"
include { LOGISTIC_REG_TRAIN }        from "${method_dir}/train"
include { LOGISTIC_REG_PREDICT }      from "${method_dir}/predict"

// NOTE: select feature could be optional, if your method not provided
// include { LOGISTIC_REG_SELECT_FEATURE }      from "${method_dir}/select_feature" 
include { MERGE_RESULT_TABLE }  from "${modulesDir}/merge_result_table"

// These are other parameters, the def is required
def method_name = "logistic_reg"
def saveMode = "method"

workflow LOGISTIC_REG {
  take:

  data_copy // ch of tuple dataset, path of mae/mu data, 
          // directories of fold, containing all txts
          // So total of three args [dataset, path, directories]
          // The third arg are the indices for each fold,
          // i.e. dir/fold1.txt, dir/fold2.txt, ...

  main:
      if (params.selectFeature == true) {
        // TODO: This bit sounds very redundant
        // Note this runs preprocess step inside
        LOGISTIC_REG_SELECT_FEATURE ( data_copy )
      } 

      // ======================================================================
      /* 
      1. Go through a specific preprocess step to get data ready for training
        TODO: Need to turn output of this to 'train_input'
      */
          
      LOGISTIC_REG_PREPROCESS ( data_copy )
      // Then join the original copy with actual folds after split
      data_copy.join(  LOGISTIC_REG_PREPROCESS.out.fold_splits, by:0 )
              .multiMap { it ->
                  input_data: [ it[0], it[1] ]              // [dataset_name, mae/mu_data]
                  // TODO: rename data_folds to mu_folds or mae_folds depending on language
                  data_folds:  [ it[0], it[3].flatten() ]   // [fold1, fold2, ... , foldk] 
                                                            // where each fold contains fold_i_tr and fold_i_te data
                }.set{ interm }
      // Transform output of preprocess to one channel input only
      interm.input_data
                    .combine(interm.mae_folds.transpose(), by: 0)
                    .set {  train_input }
      // ======================================================================
      
      /*
        2.  Training for each fold created through previous preprocessed data
            saved as `train_input`. With option of inner cross validation in  
            each  fold data.
      */

      // TODO: implement inner fold cross-validation in each LOGISTIC_REG's train
      LOGISTIC_REG_TRAIN ( train_input )

      // Do some transformation to make a multiMap that has two branches for predict
      LOGISTIC_REG_TRAIN.out.model
                  .join(LOGISTIC_REG_TRAIN.out.test_data, by: [0, 1])
                  .multiMap { it ->
                    model:      [ it[0], it[1], it[2] ] // [ dataset_name, fold_name, model ]
                    test_data:  [ it[0], it[1], it[3] ] // [ dataset_name, fold_name, test_data]
                  }.set { predict_input }

      // ======================================================================
      
      /*
        3. Predict for each fold of data throught their model and get 
        fold specific outupts. With option of inner cross validation in each 
        fold data.
      */

      LOGISTIC_REG_PREDICT (  
        predict_input.model,
        predict_input.test_data,
        Channel.value(method_name)
        )

      // ======================================================================
      
      /* 
        4. Collect results of predicted folds for each data and group dataset
          name.
      */

      // Transform output of the predictions for merging now   
      LOGISTIC_REG_PREDICT.out.result_table
                    .groupTuple(by: 2)
                    // Get the dataset name and path of these result table only
                    .map {it -> 
                      [ it[2], it[3] ] // Channel of method name and all folds (of all data)
                    }
                    .set { result_table }
      // Lastly merge it, this would be quite fast
      MERGE_RESULT_TABLE ( result_table, saveMode )

      // =====================================================================
    }
    // And emit the result back to upstream (which is another merge of different method)
    // sort of like a recursive manner?
    emit:
    csv_results = MERGE_RESULT_TABLE.out.csv_results
}

```

Theres a lot going on here, but the most important steps or things to
note are here:

``` groovy
include { LOGISTIC_REG_PREPROCESS }   from "${method_dir}/preprocess"
include { LOGISTIC_REG_TRAIN }        from "${method_dir}/train"
include { LOGISTIC_REG_PREDICT }      from "${method_dir}/predict"
```

These are groovy statements to tell nextflow to find `main.nf` files
under specified directory like `${method_dir}/preprocess`, whereas we
defined `method_dir` to be `logistic_reg` earlier.

> \[! TIP\] For now on, every of the paths that ends with a directory
> name and not file name indicating theres should be a main.nf within
> that directory.

So, this means we only have to implement these three steps: preprocess,
train, and predict under right directory structure using the provided
templates under `~/templates/nxf_scripts/`. Then, the workflow would
work expectedly.

### Implementing the preprocessing step

Now, this comes a bit of hard part, since it relates with Nextflow logic
and making concepts complicated.

We first create the preprocess script under
`~/modules/logistic_reg/preprocess/main.nf` with the contents filled up
from our template at `~/templates/nxf_scripts/method_preprocess.nf`:

``` groovy

/* 
  Use this process prepare inputs, or any necessary
  transformation/preprocessing steps to train for 
  a specific <method>

  Author: Tony Liang
*/


// Include the parse method process name output dir
include { getPublishPath } from "${modulesDir}/functions"

// Actual implementation
process LOGISTIC_REG_PREPROCESS {
  // temp variables to use
  def onSockeye = workflow.projectDir.toString().contains('/scratch')
  // process level configuration
  debug "${params.debug}" // debugs true or false by param in MESSI.config
  tag "${dataset_name}" // identifier of process when ran in parallel
  // By var before to determine what container to use
  // Uses apptainer if true otherwise docker
  
  // TODO: Need to specify a apptainer sif, and a docker URI to your container
  // Given LR is in baseR, so any R related img works
  container "${ onSockeye ?
    'codia.sif' :
    'tonyliang19/codia:latest'}"

  /* outputs store to outdir for saving and inspecting purpose */
  publishDir (
    path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}",
    mode: 'copy',
    overwrite: true
  )

  // Input and output blocks, optional true flag could be supplied
  input:
    /* 
      dataset name, complete portion of data (MAE), 
      and directory containing list of txt files, such 
      each txt is fold indices
    */
    tuple val(dataset_name), path(mae_path), path(split_dir)
  output:
    /*
    Series of folder, each represent a fold, whereas within fold there are 
    one train and test MAE data portion
    
    NOTE: it allows more output if desired, but the default here are required
    */
      
    tuple val(dataset_name), path("*fold*"),    emit: fold_splits
    path('*.log*'),  emit: log
  
  script:
    /*
    Remember the script use here needs to have the following:
      - Placed in resources/usr/bin of the directory of current nf script
      - chmod +x (is executable)
      - Add shebang !/usr/bin/env Rscript or !/usr/bin/env python on 
        top of the script
    */
    """
    preprocess_logistic_reg.R \
      --mae_path=${mae_path} \
      --split_dir=${split_dir} \
      --dataset_name=${dataset_name} > \
      ${dataset_name}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
    """
}
```

The script above is from nextflow, which declares input/output, script
used, and containers to use. It provides an abstract layer without user
to worry about how scripts should run with adequate resources in
different platforms. However, making this to work requires some
important steps fulfilled:

- Implementing a non-interactive R/Python script provided with matching
  command line arguments
- Place this script in right directory structure under
  method/preprocess/resources/usr/bin
- Give the script executable permission
- Add a shebang on top of this non-interactive script its corresponding
  interpreter
- Implementing an apptainer image, and declare it on this nextflow
  script.

So, we provided a `preprocess_logistic_reg.R` script following template
at `~/templates/cli_scripts/r_cli.R` placing it under
`~/modules/logistic_reg/preprocess/resources/usr/bin` and giving it
executable permission with `chmod +x preprocess_logistic_reg.R`:

``` r
#!/usr/bin/env Rscript

# =============================================================================
# - The shebang line is required
# - You also need to make the script executable by chmod +x script_name.R
# - The script should be placed under <method>/<action>/resources/usr/bin
# - when wring the doc for docopt, DO NOT USE tab, use spaces
# =============================================================================

# Modifications required to the script could be:
# The Usage line to add required number of arguments of input
# The Options part to defined long versions and short alias for certain para
# And you should add brief description to each of those
# The --param=<name_here_doesnt_matter_too_much>
# But it should be defined in both Usage and Options
# Lastly, update the main function accordingly and codes inside it
# It should be well contained function that you could access it from outside
# by passing params only

# -----------------------------------------------------------------------
# ALERT
# -----------------------------------------------------------------------
# You need to use spaces for the 'doc' section in order to make docopt work
# it complains if using tab
# But rest code not from the doc, could use tab over space
# =============================================================================

doc <- "This is the documentation that will appear in the terminal when you run
the script with --help. This script is for preprocessing and handling full MAE
data and split them up into folds of MAE in the following structure:

fold1/
 |___ fold1_tr_mae_data/
 |___ fold1_te_mae_data/

...

foldK/

Also, we transpose the matrix data in the maes given MAE comes in a format of 
p_j x n , while most methods accept it in n x p_j format


Usage: 
  preprocess_logistic_reg.R [options]

Options:
  --mae_path=MAE_PATH     Path to read the MAE data (full portion)
  --split_dir=SPLIT_DIR   Directory of the splits [default: splits]
  --dataset_name=DNAME    Name of the dataset as identifier
"

# This is required to convert the doc (write meaningful doc)
# to a docopt object so that it's parsable (DELETE this line later)
opt <- docopt::docopt(doc)

# You should mainly be abstracting the codes inside here to a some function
# that takes certain number of arguments, and should do everything for you
# If it's to complicated, think of getting a processed data instead of raw
# data. Or any other things that could make this abstract enough but still
# clear enough by simply looking at it


# Roxygen styles should not be worried too much here, you should have a similar
# documentation in the start of the script
# Just briefly comment on special things to notice or annotations on dealing
# edge cases of the function

# We need an additional function that parses the txts files in the split_dir
# Helper to load all test splits
load_test_splits <- function(split_dir, pattern=".txt", ...) {
  if (split_dir == "empty") {
    stop("You did not provide the directory that contains txt files of indices")
  }
  # Glob pattern
  # The split dir needs to be relative, do NOT use here::here
  # When run with nextflow, as it caches the dir inside a work directory
  idx_files <- list.files(path=split_dir, 
                          pattern=".txt", full.names = TRUE)
  # Read in data
  idx_list <- lapply(idx_files, function(f) {
    data <- scan(f, what = numeric(), quiet = TRUE)
    return(data)
  })
  
  # Check if it contains zero (hence assume it was 0index based)
  zero_indexed <- any(sapply(idx_list, function(vec) any(vec == 0)))
  # Then if true, shift all by 1
  if (zero_indexed) {
    cat("\nIndex founded to be 0 based, shift by 1 for all\n")
    idx_list <- lapply(idx_list, function(x) x + 1)
  }
  
  # Assign names based on loaded files
  idx_list <- setNames(idx_list, 
                       tools::file_path_sans_ext(basename(idx_files)))
  return(idx_list)
}

# Helper to construct MAE after splitting
reconstruct_mae <- function(mae) {
  # Given an mae with delayed matrices, we could load it into
  # memory and make it of HDF5 arrays instead
  X <- mae@ExperimentList |> lapply(as.matrix)
  col_data <- colData(mae)
  # Construct MAE
  new_mae <- MultiAssayExperiment::MultiAssayExperiment(experiments = X, 
                                                        colData = col_data)
  return(new_mae)
}

# This is the main function ran
preprocess_logistic_reg <- function(mae_path, split_dir, dataset_name) {
  # Load the mae first
  mae <- MultiAssayExperiment::loadHDF5MultiAssayExperiment(dir=mae_path, prefix="")
  # and load the splits using our helper above
  test_splits <- load_test_splits(split_dir=split_dir)
  # Some logging for debug
  message("Splitting data for", dataset_name, "\n")
  message("\nThe data is located in:", mae_path, "\n")
  message("\nThe splits are located in:", split_dir, "\n")
  
  # Then now, we are going to process for each fold, separate its train and test
  # portion into separate MAE, and place these two mae in same directory as 
  # described before
  fold_names <- names(test_splits)
  for (fold_name in fold_names) {
      # First subset both
      split <- test_splits[[fold_name]]
      # Then we call the other helper that reconstruct an mae
      # this is required, otherwise you will get a delayedMatrix 
      tr_mae <- mae[, -split, drop=TRUE] |> reconstruct_mae()
      te_mae <- mae[, split, drop=TRUE] |> reconstruct_mae()
      # Then save each fold's train and test portion as subdirectory of fold name
      message("\nSaving for", fold_name, "\n")
      if (!dir.exists(fold_name)) {
        dir.create(fold_name)
      }
      tr_path <- file.path(fold_name, paste0(fold_name, "_tr"))
      te_path <- file.path(fold_name, paste0(fold_name, "_te"))
      # The train portion
      MultiAssayExperiment::saveHDF5MultiAssayExperiment(tr_mae, dir=tr_path,
                                                        prefix="train")
      # The test portion
      MultiAssayExperiment::saveHDF5MultiAssayExperiment(te_mae, dir=te_path,
                                                        prefix="test")
      message("\nSaved for", fold_name, "\n")                                                      
    }
}
```

``` r
# Then here actually execute the function above
preprocess_logistic_reg(
  mae_path = opt[["--mae_path"]], 
  split_dir = opt[["--split_dir"]],
  dataset_name = opt[["--dataset_name"]]
)
```

So say, if we running this with some toy data and splits of 2 folds

``` r
# First setup some parameters
toy_dir <- here("data/tutorial_data")
mae_path <- here(toy_dir, "rosmap_mae_data")
split_dir <- here(toy_dir, "splits")
```

Then, we could inspect the mae and the splits indices first without
using the function above yet

``` r
# Load the mae and inspect it, this is the rosmap data
rosmap_mae <- loadHDF5MultiAssayExperiment(mae_path)
rosmap_mae
```

    ## A MultiAssayExperiment object of 3 listed
    ##  experiments with user-defined names and respective classes.
    ##  Containing an ExperimentList class object of length 3:
    ##  [1] epigenomics: HDF5Matrix with 200 rows and 351 columns
    ##  [2] genomics: HDF5Matrix with 200 rows and 351 columns
    ##  [3] transcriptomics: HDF5Matrix with 200 rows and 351 columns
    ## Functionality:
    ##  experiments() - obtain the ExperimentList instance
    ##  colData() - the primary/phenotype DataFrame
    ##  sampleMap() - the sample coordination DataFrame
    ##  `$`, `[`, `[[` - extract colData columns, subset, or experiment
    ##  *Format() - convert into a long or wide DataFrame
    ##  assays() - convert ExperimentList to a SimpleList of matrices
    ##  exportClass() - save data to flat files

And for the splits

``` r
# Load the splits and inspect it as well
load_test_splits(split_dir)
```

    ## 
    ## Index founded to be 0 based, shift by 1 for all

    ## $fold_1
    ##   [1]   4   5   6  11  15  17  18  20  22  24  28  29  30  34  36  37  38  41
    ##  [19]  44  46  47  48  51  53  55  58  61  62  63  64  67  69  71  73  74  75
    ##  [37]  76  78  80  81  82  83  88  93  94  98  99 101 102 103 106 109 110 112
    ##  [55] 120 124 125 126 128 129 131 134 135 136 140 141 143 144 145 150 151 152
    ##  [73] 153 155 157 159 160 163 164 165 166 167 169 170 173 174 179 182 184 186
    ##  [91] 187 189 192 196 197 198 200 204 206 207 208 209 213 215 217 222 223 226
    ## [109] 227 230 233 234 235 237 246 247 250 251 252 253 254 255 258 259 261 262
    ## [127] 263 265 268 269 271 272 274 277 278 279 282 284 285 286 287 289 294 295
    ## [145] 296 297 299 302 303 304 306 307 308 309 311 314 315 318 319 322 323 327
    ## [163] 328 329 330 331 332 334 336 337 340 343 345 346 347 350
    ## 
    ## $fold_2
    ##   [1]   1   2   3   7   8   9  10  12  13  14  16  19  21  23  25  26  27  31
    ##  [19]  32  33  35  39  40  42  43  45  49  50  52  54  56  57  59  60  65  66
    ##  [37]  68  70  72  77  79  84  85  86  87  89  90  91  92  95  96  97 100 104
    ##  [55] 105 107 108 111 113 114 115 116 117 118 119 121 122 123 127 130 132 133
    ##  [73] 137 138 139 142 146 147 148 149 154 156 158 161 162 168 171 172 175 176
    ##  [91] 177 178 180 181 183 185 188 190 191 193 194 195 199 201 202 203 205 210
    ## [109] 211 212 214 216 218 219 220 221 224 225 228 229 231 232 236 238 239 240
    ## [127] 241 242 243 244 245 248 249 256 257 260 264 266 267 270 273 275 276 280
    ## [145] 281 283 288 290 291 292 293 298 300 301 305 310 312 313 316 317 320 321
    ## [163] 324 325 326 333 335 338 339 341 342 344 348 349 351

> TODO: Need to explain better here? and introduce the nextflow concept
> earlier
