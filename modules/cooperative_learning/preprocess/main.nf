// TODO: Have process level local params for debug purposes

// Include the parse method process name output dir
include { getPublishPath } from "${modulesDir}/functions"

process COOPERATIVE_LEARNING_PREPROCESS {
  // Temp variables
  def onSockeye = workflow.projectDir.toString().contains('/scratch')
  /* Directives for process */
  debug "${params.debug}" // default is true
  tag "${dataset_name}"
  label 'process_single'
  container "${ onSockeye ?
    'codia.sif' :
    'tonyliang19/codia:latest'}"
  
  // More special publish dir by getting method/method_abc to method/abc
  publishDir (
    path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}",
    mode: 'copy',
    overwrite: true
  )
  /*Input and output blocks*/
  input:
  tuple val(dataset_name), path(mae_path), path(split_dir)
  output:
  /*
    Series of folder, each represent a fold, whereas within fold there are 
    one train and test MAE data portion
  */
  tuple val(dataset_name), path("*fold*"),   emit: fold_splits
  path('*.log'),                             emit: log
  
  /*
    Main script logic
  */
  script:
  // This script is in bin/
  """
  split_mae.R \
  --mae_path=${mae_path} \
  --split_dir=${split_dir} \
  --dataset_name=${dataset_name} \
  --transpose > \
  ${dataset_name}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
  """
  stub:
  """
  echo ${dataset_name}
  echo ${mae_path}
  echo ${split_dir}
  """
}