process SPLIT_TRAIN_TEST {
	// process metadata and configs
	// Vars stuff
	//def isRemote = workflow.containerEngine == 'apptainer' && !workflow.profile == 'standard'
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${dataset_name}"
	label 'process_single'
	debug	"${params.debug}"
	container "${ onSockeye  ? 
		'save_simulate.sif' : 
		'tonyliang19/save_simulate:latest' }"
	publishDir (
		path: "${params.outdir}/${task.process.tokenize(':').join('/').toLowerCase()}",
		//saveAS: { fn -> fn.endsWith(".log") ? "${id}/$fn" : fn },
		mode: 'copy',
		overwrite: true
	)


	input:
		tuple val(dataset_name), path(mu_path)
		val(num_splits)
		val(output_dir)

	output:
	 	// Should expect a folder containing K txt files with test indices
		tuple val(dataset_name), path("${dataset_name}/${output_dir}"), 	emit:	splits_indices
		tuple val(dataset_name), path("${dataset_name}/*.log"), 					emit: split_log // Log files
	script:
		// Read the MuData portion only to split it
		"""
		mkdir -p ${dataset_name}/${output_dir}
		split_tr_te.py	${mu_path}	\
										--num_splits=${num_splits}	\
										--output_dir=${dataset_name}/${output_dir} > \
										${dataset_name}/${dataset_name}-${task.process.tokenize(':')[-1].toLowerCase()}.log
		"""
	stub:
		"""
		mkdir ${output_dir}
		touch ${output_dir}/a.txt
		touch ${output_dir}/b.txt
		touch test.log
		"""
}