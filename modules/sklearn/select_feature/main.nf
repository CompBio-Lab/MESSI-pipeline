// Include util functions
include { getPublishPath } from "${modulesDir}/functions"


process SKLEARN_SELECT_FEATURE {
  // Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${model_name}-${dataset_name}"
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
    each (model_name)
  output:
    path("*.csv"),    emit: features
    path("*.log"),    emit: log

  script:
  // The selected features, note have to run preprocess inside this step
  // which is just a convert data format only
  """
  sklearn_select_features.py  --dataset_name=${dataset_name} \
                            --data_path=${data_path} \
                            --model_name=${model_name} > \
                            sklearn-select_features_${model_name}-${dataset_name}.log

  """
}