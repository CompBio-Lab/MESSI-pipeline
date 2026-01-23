// Include util functions
include { getPublishPath } from "${modulesDir}/functions"


process CARET_MULTIMODAL_SELECT_FEATURE {
  // Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${dataset_name}"
	debug true
  label 'process_high'
	container "${ onSockeye  ?
		'caret_multimodal.sif' :
		'tonyliang19/caret_multimodal:latest' }"

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
  caret_multimodal_select_feature.R  --dataset_name=${dataset_name} \
                            --data_path=${data_path} > \
                            caret_multimodal-${dataset_name}.log

  """
}