// This should be tempalte for preprocess_methods

/* 
  Use this process to parse basic metadata of a multiomics
  dataset like its number of observations in each omics, and 
  numbers of features

  Author: Tony Liang
*/
// Include the parse method process name output dir
//include { getPublishPath } from "${modulesDir}/functions"
// TODO: Replace name here
process PARSE_METADATA {
  // process level configuration
  debug "${params.debug}" // debugs true or false by param in MESSI.config
  // tag "${dataset_name}" // identifier of process when ran in parallel
  // By var before to determine what container to use
  // Uses apptainer if true otherwise docker
  label "generic"


  /* outputs store to outdir for saving and inspecting purpose */
  publishDir (
    path: "${params.outdir}/parse_metadata",
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
    path(mae_path_list)
  // TODO: This part could be different dependent on method
  output:
    /*
    Series of folder, each represent a fold, whereas within fold there are 
    one train and test MAE data portion
    */
    path("parsed_metadata.csv")
    path("parsed_metadata.log")
    //path('*.log*'),  emit: log
  
  /* Execution blocks below, worth to use stub option first */
  script:
    // TODO: could have a python version of the script, but instead it
    // takes the mu_path
    """
    parse_metadata.R \
      --mae_path_list="${mae_path_list}" > \
      parsed_metadata.log
    """
  stub:
  // TODO: implement this stub for current process, should give same as output block
    """
    echo "${mae_path_list}"
    """
}
