// This should be tempalte for preprocess_methods

/* 
  Use this process prepare inputs, or any necessary
  transformation/preprocessing steps to train for 
  a specific DIABLO

  Steps to carry here:

  Splitting the MAEs only into train and test dirs of MAE like below:
  - test_fold_i
    - test_fold_i_tr
      - train_experiments.h5
      - train_mae.rds
    - test_fold_i_te
      - test_experiments.h5
      - test_mae.rds
  Note, the data here are transposed already, given DIABLO requires it to 
  be in the format of Rows x Columns


  Author: Tony Liang
*/

// Include the parse method process name output dir
include { getPublishPath } from "${modulesDir}/functions"

process DIABLO_PREPROCESS {
  // temp variables to use
  // process level configuration
  debug "${params.debug}" // debugs true or false by param in MESSI.config
  label 'process_single'
  tag "${dataset_name}" // identifier of process when ran in parallel
  // By var before to determine what container to use
  // Uses apptainer if true otherwise docker
  label 'codia'

  /* outputs store to outdir for saving and inspecting purpose */
  publishDir (
    //path: "${params.outdir}/${task.process.tokenize(':')[-1].toLowerCase()}/${dataset_name}",
    path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}",
    mode: 'copy',
    overwrite: true
  )

  // Input and output blocks, optional true flag could be supplied
  input:
    /* data name identifier, MAE portion of data , and dir that contains txt in it" */
    tuple val(dataset_name), path(mae_path), path(split_dir)
  // TODO: This part could be different dependent on method
  output:
    /*
    Series of folder, each represent a fold, whereas within fold there are one train and test 
    MAE data portion
    */
    tuple val(dataset_name), path("*fold*"),   emit: fold_splits
    path('*.log'),                             emit: log
  
  /* Execution blocks below, worth to use stub option first */
  script:
    """
    split_mae.R \
      --mae_path=${mae_path} \
      --split_dir=${split_dir} \
      --dataset_name=${dataset_name} \
      --transpose > \
      ${dataset_name}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
    
    echo ${dataset_name} > dataset_name
    """
  stub:
  // TODO: implement this stub for current process, should give same as output block
    """
    mkdir fold_dir
    touch the_log_file.log
    """
}
