/*
  Process to expand a MuData into one single-modality MuData per
  omics. Part of the single-modality mode (params.single_modality_mode).

  Input : tuple val(dataset_name), path("<dataset>_processed.h5mu")
  Output: tuple val(dataset_name), path("<dataset>-<mod>_processed.h5mu" ...)
          NOTE: the val is still the PARENT dataset name; the subworkflow
          derives the child (unimodal) dataset names from the file names via
          flatMap, because a process output tuple cannot fan out per file.
*/

process SPLIT_MODALITY {
  tag "${dataset_name}"
  label 'process_low'
  label 'generic'
  publishDir (
    path: "${params.outdir}/${task.process.tokenize(':').join('/').toLowerCase()}/${dataset_name}",
    mode: 'copy',
    overwrite: true
  )

  input:
  tuple val(dataset_name), path(mu_path)

  output:
  tuple val(dataset_name), path("${dataset_name}-*_processed.h5mu"),  emit: unimodal_files
  tuple val(dataset_name), path("*.log"),                             emit: log

  script:
  """
  split_modalities.py \
    --mu_path=${mu_path} \
    --dataset_name=${dataset_name} > \
    ${dataset_name}-split_modality.log
  """
}
