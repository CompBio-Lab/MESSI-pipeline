// Nextflow process
// Author: Tony Liang


// Handles the GOAT method listed the Reference section of top-level README

process TRAIN_GOAT {
	// This label is defined in nextflow.config
	label 'python'
	label 'gpu'
	debug true

	tag "${id}"
	
	input:
		tuple val(id), path(mu_path)
		each test_splits
	output:
		path('*mod*'), emit: mod
		path('*prediction*'), emit: pred
		path('*log*'), emit: log
	script:
	// Note this Python bin is directly from the container defined above ^
	// Some of the variables here that you don see defined explitcily in the input
	// is likely defined in the top-level nextflow.config
	"""
	run_goat.py
	"""
  stub:
	"""
	echo ${id}
	echo ${mu_path}
	echo 'some text' > text.log
	touch prediction.csv
	touch model
	"""

}