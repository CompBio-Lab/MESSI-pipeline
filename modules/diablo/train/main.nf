// Nextflow process
// Author: Tony Liang


// Handles the DIABLO method listed the Reference section of top-level README
include { getPublishPath } from "${modulesDir}/functions"
process DIABLO_TRAIN {
	// Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	def method_name = "diablo"
	tag "${dataset_name}-${fold_path.name}-design_${design}-ncomp_${ncomp}"
	//debug	"${params.debug}"
	debug true
	label 'process_medium'
	container "${ onSockeye  ?
		'codia.sif' :
		'tonyliang19/codia:latest' }"
	// Parse this path
	publishDir (
		//path: "${params.outdir}/${task.process.tokenize(':')[-1].toLowerCase()}/${dataset_name}/${fold_path.name}",
		path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}/${fold_path.name}",
		//path: "${params.outdir}/${pub_dir(task)}/${dataset_name}/${fold_path.name}"
		mode: 'copy',
		//saveAs: { file },
		overwrite: true
	)


	// Labels
	label 'low_mem'
	label 'cpu'
	label 'codia'

	input:
		tuple val(dataset_name), path(mae_path), path(fold_path)
		val(run_inner_cv)
		val(ncomp)
		each(design)
	output:
		tuple val(dataset_name), val(fold_path.name), val("${method_name}-${design}"), path('*model.rds'),			 	emit: model
		tuple val(dataset_name), val(fold_path.name), val("${method_name}-${design}"), path('*test_data.rds'),	 	emit: test_data
		tuple val(dataset_name), val(fold_path.name), val("${method_name}-${design}"), path('*weights.txt'),			emit: weights
		tuple val(dataset_name), val(fold_path.name), val("${method_name}-${design}"), path('*log*'), 						emit: log
	script:
		def data_label = "${dataset_name}-${fold_path.name}"
		if (run_inner_cv)
			"""
			run_diablo.R \
				--mae_path=${mae_path} \
				--label=${data_label} \
				--fold_path=${fold_path} \
				--run_inner_cv > \
				${data_label}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
			echo ${dataset_name} > dataset_name
			"""
		else
			"""
			run_diablo.R \
				--mae_path=${mae_path} \
				--label=${data_label} \
				--design=${design} \
				--ncomp=${ncomp} \
				--fold_path=${fold_path} > \
				${data_label}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
			echo ${dataset_name} > dataset_name
			"""
	stub:
	"""
	echo ${dataset_name}
	echo ${mae_path}
	echo 'some text' > text.log
	touch prediction.csv
	touch model
	"""
}