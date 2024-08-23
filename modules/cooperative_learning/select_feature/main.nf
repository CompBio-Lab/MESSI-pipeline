// Include util functions
include { getPublishPath } from "${modulesDir}/functions"


process COOPERATIVE_LEARNING_SELECT_FEATURE {
  // Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${dataset_name}"
	debug true
  label 'process_high'
	container "${ onSockeye  ?
		'codia.sif' :
		'tonyliang19/codia:latest' }"

	publishDir (
		path: "${params.outdir}/${task.process.tokenize(':').join('/').toLowerCase()}/${dataset_name}",
		mode: 'copy',
		overwrite: true
	)

	// Labels
	label 'low_mem'
	label 'cpu'
	label 'codia'
  
  
  /* Input and output blocks*/
  // This is triggered from FEATURE_SELECTION:CPLR_SELECT_FEATURE
  input:
    tuple val(dataset_name), path(mae_path)
    val(n_percent)
  output:
    path("*.csv"),  emit: features
    path("*plot*"), emit: plot
    path("*.log"),  emit: log

  script:
  // The selected features, note have to run preprocess inside this step
  // which is just a convert data format only
  """
  cplr_select_features.R  --dataset_name=${dataset_name} \
                          --mae_path=${mae_path}  > \
                          cplr-select_features_${dataset_name}.log

  """



}