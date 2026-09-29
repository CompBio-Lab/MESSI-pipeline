/* 
  Process to read in real data (MAE portion) and standardize it for
  downstream uses. Things done here including:
   - TODO: Add what should be done in here
   - Transform response vector to factor chr
   - Make MAE in bioc format, this would overwrite the original content
   - etc.
*/

process PREPARE_MAE_DATA {
	/* process metadata and configs */
	tag "${dataset_name}"
  label 'process_low'
  label 'generic'
	publishDir (
		path: "${params.outdir}/${task.process.tokenize(':').join('/').toLowerCase()}/${dataset_name}",
		saveAS: { file },
		mode: 'copy',
		overwrite: true
	)

  /* Important blocks */
  input:
  tuple val(dataset_name), path(mae_path)
  val(filter_low_var)
  output:
  tuple val(dataset_name), path("${dataset_name}*processed*mae_data"),  emit: mae_data // Directory containing MultiAssayExperiment
  tuple val(dataset_name), path("*.log"),                     emit:log
  script:
  """
  transform_mae_format.R --mae_path=${mae_path} \
    --dataset_name=${dataset_name} \
    --filter_low_var=${filter_low_var} > \
    ${dataset_name}.log
  """
}
