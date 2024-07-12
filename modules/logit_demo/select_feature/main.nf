// Include util functions
include { getPublishPath } from "${modulesDir}/functions"


process LOGIT_DEMO_SELECT_FEATURE {
  // Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${dataset_name}"
	debug true
  label 'process_high'
	container "${ onSockeye  ?
		'logit_demo.sif' :
		'tonyliang19/logit_demo:latest' }"

	publishDir (
		path: "${params.outdir}/${task.process.tokenize(':').join('/').toLowerCase()}/${dataset_name}",
		mode: 'copy',
		overwrite: true
	)

  /* Input and output blocks*/
  input:
    tuple val(dataset_name), path(data_path)
    val (n_percent)
  output:
    path("*.csv"),    emit: features
    path("*plot*"),   emit: plot
    path("*.log"),    emit: log

  script:
  // The selected features, note have to run preprocess inside this step
  // which is just a convert data format only
  """
  logit_demo_select_features.R  --dataset_name=${dataset_name} \
                            --data_path=${mae_path} \
                            --n_percent=${n_percent} > \
                            ${dataset_name}.log

  """
}