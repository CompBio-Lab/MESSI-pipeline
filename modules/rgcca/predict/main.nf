// Include the parse method process name output dir
include { getPublishPath } from "${modulesDir}/functions"

process RGCCA_PREDICT {
	// Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${dataset_name}-${fold_name}-${method}"
	debug "${params.debug}"
  label 'process_single'
	container "${ onSockeye  ?
		'rgcca.sif' :
		'tonyliang19/rgcca:latest' }"

	publishDir (
		path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}/${fold_name}",
		mode: 'copy',
		overwrite: true
	)

	/*
    Custom labels to add for the method if required GPU access, 
    large mem usage, etc.
  */
	label 'low_mem'
	label 'cpu'
	label 'codia'

  /*
    Given RGCCA itself has many methods available, so we have an extra input here
  */

	input:
    tuple val(dataset_name), val(fold_name), val(method), path(model)
		tuple val(dataset_name), val(fold_name), val(method), path(test_path)
	/*
    Minimal requierd output are the path to predicted results in a csv format
    and the log file
  */
  output:
    tuple val(dataset_name), val(fold_name), val(method), path("*result*"),  emit: result_table
		tuple val(dataset_name), val(fold_name), val(method), path('*log*'),     emit: log
	
  /*
  TODO:
    - Rename the script to predict_<method>.<extension of the script>
    - Place the script under modules/method/predict/resources/usr/bin
      - Then chmod +x predict_<method>.<ext>, after renamed and created the script
  */
  script:
		def data_label = "${dataset_name}-${fold_name}-${method}"
		// TODO: temporal fix here
		def design = "${method}.tokenize('-')[-1]}"
		"""
    predict_rgcca.R \
      --model=${model} \
      --test_path=${test_path} \
      --method=${method} \
      --label=${data_label} \
      --design=${design} > \
      ${data_label}-${getPublishPath(task.process).tokenize('/')[-1]}.log
		"""
  stub:
    """
    echo ${dataset_name}
    echo ${fold_name}
    echo ${model}
    echo ${test_path}
    """
}
