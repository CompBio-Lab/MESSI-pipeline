// Include the parse method process name output dir
include { getPublishPath } from "${modulesDir}/functions"

process INTEGRAO_PREDICT {
	// Vars stuff
	tag "${dataset_name}-${fold_name}"
	debug "${params.debug}"
	label 'integrao'

	publishDir (
		path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}/${fold_name}",
		mode: 'copy',
		overwrite: true
	)

	/*
    Custom labels to add for the method if required GPU access, 
    large mem usage, etc.
  */
	label 'process_medium'
        label 'gpu'
  /*
    These are minimal required input, the dataset name, current fold, and path
    to trained model and test data for current fold
  */
	input:
    tuple val(dataset_name), val(fold_name), path(model_dir)
    tuple val(dataset_name), val(fold_name), path(preprocessed_data_dir)
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
    export MPLCONFIGDIR="./mplconfigdir"
    integrao_predict.py \
      --model_dir=${model_dir} \
      --preprocessed_data_dir=${preprocessed_data_dir} \
      --dataset_name=${dataset_name} \
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
