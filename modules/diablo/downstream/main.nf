// This should be tempalte for preprocess_methods

/* 
  Use this process prepare inputs, or any necessary
  transformation/preprocessing steps to train for 
  a specific <method>

  Author: Tony Liang
*/

/*
  Add small description of what the method input requirement is

  Describe file/directory structure of the read data

*/

// Include the parse method process name output dir
include { getPublishPath } from "${modulesDir}/functions"


// TODO: Replace name here
process DIABLO_DOWNSTREAM {
  // temp variables to use
  def onSockeye = workflow.projectDir.toString().contains('/scratch')
  // process level configuration
  debug "${params.debug}" // debugs true or false by param in MESSI.config
  label 'process_single'
  tag "${dataset_name}" // identifier of process when ran in parallel
  // By var before to determine what container to use
  // Uses apptainer if true otherwise docker
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
      dataset name, complete portion of data (MAE or mu), 
      and directory containing list of txt files, such 
      each is fold indices
    */
    tuple val(dataset_name), path(mae_path), path(split_dir)
  output:
    tuple val(dataset_name), path("${dataset_name}*correlation_circle_plot*")
    tuple val(dataset_name), path("${dataset_name}*individual_samples_plot*")
    tuple val(dataset_name), path("${dataset_name}*block_samples_arrow_plot*")
    tuple val(dataset_name), path("${dataset_name}*variables_correlation_circle_plot*")
    tuple val(dataset_name), path("${dataset_name}*variables_loadings_plot*")

  /* Execution blocks below, worth to use stub option first */
  script:
    """
    diablo_downstream_analysis.R \
      --mae_path=${mae_path} \
      --dataset_name=${dataset_name} \
      --makePlot > \
      ${dataset_name}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
    """
  stub:
  // TODO: implement this stub for current process, should give same as output block
    """
    echo ${dataset_name}
    """
}
