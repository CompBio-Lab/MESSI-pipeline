/* 
  Process to read in real data (Mu portion) and standardize it for
  downstream uses. Things done here including:
   - TODO: Add what should be done in here
   - Transform response vector to categorical str (yes or no), case sensitive
*/

process PREPARE_MU_DATA {
  def onSockeye = workflow.projectDir.toString().contains('/scratch')
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
  tuple val(dataset_name), path(mu_path)
  val(filter_low_var)
  output:
  tuple val(dataset_name), path("${dataset_name}*processed*.h5mu"),  emit: mu_data // Path to processed h5mu file
  tuple val(dataset_name), path("*.log"),                 emit: log
  """
  transform_mudata_format.py --mu_path=${mu_path} \
    --dataset_name=${dataset_name} \
    --filter_low_var=${filter_low_var} > \
    ${dataset_name}.log
  """
}
