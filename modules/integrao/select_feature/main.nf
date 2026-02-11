// Include util functions
include { getPublishPath } from "${modulesDir}/functions"


process INTEGRAO_SELECT_FEATURE {
  // Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${dataset_name}"
	debug true
  label 'process_high'
	container "${ onSockeye  ?
		'integrao.sif' :
		'tonyliang19/integrao:latest' }"

	publishDir (
		path: "${params.outdir}/${task.process.tokenize(':').join('/').toLowerCase()}/${dataset_name}",
		mode: 'copy',
		overwrite: true
	)

  /* Input and output blocks*/
  input:
    tuple val(dataset_name), path(data_path)
  output:
    path("*.csv"),    emit: features
    path("*plot*"),   optional: true,   emit: plot
    path("*.log"),    emit: log

  script:
  // The selected features, note have to run preprocess inside this step
  // which is just a convert data format only
  """
  export MPLCONFIGDIR="./mplconfigdir"
  integrao_select_feature.py  --dataset_name=${dataset_name} \
                            --data_path=${data_path} > \
                            integrao-${dataset_name}.log

  """
}