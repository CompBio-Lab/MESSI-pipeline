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
process LOGIT_DEMO_PREPROCESS {
  // temp variables to use
  def onSockeye = workflow.projectDir.toString().contains('/scratch')
  // process level configuration
  debug "${params.debug}" // debugs true or false by param in MESSI.config
  tag "${dataset_name}" // identifier of process when ran in parallel
  // By var before to determine what container to use
  // Uses apptainer if true otherwise docker
	container "${ onSockeye  ?
		'logit_demo.sif' :
		'tonyliang19/logit_demo:latest' }"

  label "process_low"

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
    tuple val(dataset_name), path(data_path), path(split_dir)
  // TODO: This part could be different dependent on method
  output:
    /*
    Series of folder, each represent a fold, whereas within fold there are 
    one train and test MAE data portion
    */
    tuple val(dataset_name), path("*fold*"),    emit: fold_splits
    tuple val(dataset_name), path('*.log*'),    emit: log
  
  /* Execution blocks below, worth to use stub option first */
  script:
    /*
    Remember the script use here needs to have the following:
      - Placed in bin/ or resources/usr/bin
      - chmod +x (is executable)
      - Add shebang !/usr/bin/env Rscript or !/usr/bin/env python on 
        top of the script namex
    TODO:
      - some optional transpose
      - rename the cli arg name like data_path to one of:
        - mae_path
        - mu_path
    */
    """
    logit_demo_preprocess.R \
      --data_path=${data_path} \
      --split_dir=${split_dir} \
      --dataset_name=${dataset_name} > \
      ${dataset_name}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
    """
  stub:
  // TODO: implement this stub for current process, should give same as output block
    """
    echo ${dataset_name}
    touch ${dataset_name}_fold_1
    """
}
