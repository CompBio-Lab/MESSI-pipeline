// This should be template for preprocess_methods

/*
  Use this process prepare inputs, or any necessary
  transformation/preprocessing steps to train for
  a specific <method>

  Survival variant: input MuData obs must contain 'time' and 'status'
  (1 = event, 0 = censored). Fold txt files contain test indices.
*/

include { getPublishPath } from "${modulesDir}/functions"

process SKSURV_PREPROCESS {
  debug "${params.debug}"
  tag "${dataset_name}"
  label 'sksurv'
  label "process_low"

  publishDir (
    path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}",
    mode: 'copy',
    overwrite: true
  )

  input:
    tuple val(dataset_name), path(data_path), path(split_dir)

  output:
    tuple val(dataset_name), path("*fold*"),    emit: fold_splits
    tuple val(dataset_name), path('*.log*'),    emit: log

  script:
    """
    sksurv_preprocess.py \
      --data_path=${data_path} \
      --split_dir=${split_dir} \
      --dataset_name=${dataset_name} > \
      ${dataset_name}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
    """
  stub:
    """
    echo ${dataset_name}
    touch ${dataset_name}_fold_1
    """
}
