// Include util functions
include { getPublishPath } from "${modulesDir}/functions"


process SKLEARN_SELECT_FEATURE {
  // Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${dataset_name}"
	debug true
  label 'process_high'
	container "${ onSockeye  ?
		'sklearn.sif' :
		'tonyliang19/sklearn:latest' }"

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
  sklearn_select_features.py  --dataset_name=${dataset_name} \
                            --data_path=${mae_path} \
                            --n_percent=${n_percent} > \
                            ${dataset_name}.log

  """
}