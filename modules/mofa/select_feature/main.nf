// Include util functions
include { getPublishPath } from "${modulesDir}/functions"


process MOFA_SELECT_FEATURE {
  // Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${dataset_name}"
	debug true
  label 'process_high'
	container "${ onSockeye  ?
		'mofa.sif' :
		'tonyliang19/mofa:latest' }"

	publishDir (
		path: "${params.outdir}/${task.process.tokenize(':').join('/').toLowerCase()}/${dataset_name}",
		mode: 'copy',
		overwrite: true
	)

  /* Input and output blocks*/
  input:
    tuple val(dataset_name), path(mae_path)
    val (n_percent)
  output:
    path("*.csv"),                  emit: features
    path("*plot*"), optional:true,  emit: plot
    path("*.log"),                  emit: log

  script:
  // The selected features, note have to run preprocess inside this step
  // which is just a convert data format only
  """
  mofa_select_features.R  --dataset_name=${dataset_name} \
                            --mae_path=${mae_path} \
                            --n_percent=${n_percent} > \
                            ${dataset_name}.log

  """
}