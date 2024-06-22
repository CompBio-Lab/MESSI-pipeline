// Include util functions
include { getPublishPath } from "${modulesDir}/functions"


process MOGONET_SELECT_FEATURE {
  // Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${dataset_name}"
	debug true
  label 'process_high'
	container "${ onSockeye  ?
		'mogonet.sif' :
		'tonyliang19/mogonet:latest' }"

	publishDir (
		path: "${params.outdir}/${task.process.tokenize(':').join('/').toLowerCase()}/${dataset_name}",
		mode: 'copy',
		overwrite: true
	)

	// Labels
	label 'low_mem'
	label 'gpu'
  
  /* Input and output blocks*/
  input:
    tuple val(dataset_name), path(mu_path)
    val(n_percent)
  output:
    path("*.csv"), emit: features
    path("*.log"), emit: log

  script:
  // The selected features, note have to run preprocess inside this step
  // which is just a convert data format only
  """
  mogonet_select_features.py  --dataset_name=${dataset_name} \
                              --mu_path=${mu_path} \
                              --n_percent=${n_percent} > \
                              ${dataset_name}.log

  """
}