// Include the parse method process name output dir
include { getPublishPath } from "${modulesDir}/functions"

process {{ method|upper }}_PREDICT {
	// Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${dataset_name}-${fold_name}"
	debug "${params.debug}"
	container "${ onSockeye  ?
		'{{ method|lower }}.sif' :
		'{{ docker_user|lower }}/{{ method|lower }}:latest' }"

	publishDir (
		path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}/${fold_name}",
		mode: 'copy',
		overwrite: true
	)

	/*
    Custom labels to add for the method if required GPU access, 
    large mem usage, etc.
  */
	label 'process_low'
  /*
    These are minimal required input, the dataset name, current fold, and path
    to trained model and test data for current fold
  */
	input:
    tuple val(dataset_name), val(fold_name), path(model_path)
		tuple val(dataset_name), val(fold_name), path(test_path)
    val(method_name)
	/*
    Minimal requierd output are the path to predicted results in a csv format
    and the log file
  */
  output:
    tuple val(dataset_name), val(fold_name), val(method_name), path("*result*"),  emit: result_table
		tuple val(dataset_name), val(fold_name), val(method_name), path('*log*'),     emit: log
	
  /*
  TODO:
    - Rename the script to predict_<method>.<extension of the script>
    - Place the script under modules/method/predict/resources/usr/bin
      - Then chmod +x predict_<method>.<ext>, after renamed and created the script
  */
  script:
		def data_label = "${dataset_name}-${fold_name}"
		"""
    {{ method|lower }}_predict.{{ ext }} \
      --model_path=${model_path} \
      --test_path=${test_path} \
			--label=${data_label} > \
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