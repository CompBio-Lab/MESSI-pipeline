// Nextflow process
// Author: Tony Liang


// Handles the MOGONET method listed the Reference section of top-level README
// Include the parse method process name output dir
include { getPublishPath } from "${modulesDir}/functions"


// TODO: confirm the output from each trained network from mogonet
process MOGONET_TRAIN {
	// This label is defined in nextflow.config
	// Vars stuff
	// Process configurations
	tag "${dataset_name}-${fold_path.name}-he${he_base_dim}"
	label 'python'
	label 'process_medium'
	label 'gpu'
	debug "${params.debug}"
	label 'mogonet'
	// Saving outputs
	publishDir (
		path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}/${fold_path.name}",
		mode: 'copy',
		overwrite: true
	)

	// Input and output blocks
	input:
		tuple val(dataset_name), path(fold_path) // complete dir is directory containing X and y separated
		val(he_base_dim) // base dimension for the HE layer
	output:
		tuple val(dataset_name), val(fold_path.name), path('*.pt'), 	emit: model
		tuple val(dataset_name), val(fold_path.name), path('*.pkl'), 	emit: test_data
		tuple val(dataset_name), val(fold_path.name), path('*.csv'), 	emit: metadata
		tuple val(dataset_name), val(fold_path.name), path('*.log'),	emit: log
	script:
	// Note this Python bin is directly from the container defined above ^
	// Some of the variables here that you don see defined explitcily in the input
	// is likely defined in the top-level nextflow.config
		def data_label = "${dataset_name}-${fold_path.name}"
		"""
		run_mogonet.py \
			--fold_path=${fold_path} \
			--label=${data_label} \
			--he_base_dim=${he_base_dim} > \
			${data_label}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
		"""
	stub:
		"""
		echo ${dataset_name}
		echo 'some text' > text.log
		touch prediction.csv
		touch model
		"""
}