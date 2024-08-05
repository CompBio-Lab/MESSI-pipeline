/*
    This process aims to simulate the data, takes in a map/dictionary of 
    parameters to control the data-generating process.

    Input:  val(grid), combination of parameters
            output_format, output format to generate
    Whereas you could acess its parameters by grid.<key_name>, i.e. grid.number

    Possible parameters are:
    - dataset_name      # Unique identifier of each combination
    - number            # of observations
    - latent_predictors # of latent predictors
    - num_predictors    # of variables)
    - sigma             Controls noise of data

    Output is then organized by two elements:
    - ~~1 tuple of paths to x, y, z matrices in the sim_data channel~~
    - ~~1 path to the log file of the process~~

*/

process SIMULATE_INTERSIM {
	// Vars stuff
	//def isRemote = workflow.containerEngine == 'apptainer' && !workflow.profile == 'standard'
	debug false
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	// process metadata and configs
	tag "${grid.dataset_name}-${output_format}"
	label 'process_medium'
	container "${ onSockeye ? 
		'intersim.sif' : 
		'tonyliang19/intersim:latest' }"
	publishDir (
		path: "${params.outdir}/${task.process.tokenize(':')[-1].toLowerCase()}/${grid.dataset_name}",
		saveAS: { file },
		mode: 'copy',
		overwrite: true
	)
	// Input goes here
	input:
		val  grid 					// Combinations of parameters, key-value pair, access element by grid.xxx
		each output_format 	// Output type of data to generate, one of MAE or MuData
	// Possible output for downstream
	output:
		// The optional MUST be true here, since it should output one of MAE or MuData at a time
		tuple val(grid.dataset_name), path('*mae*'), 	optional: true, emit: sim_mae
		tuple val(grid.dataset_name), path('*.h5mu'), optional: true, emit: sim_mu
		tuple val(grid.dataset_name), path('*.log'),									emit: sim_log
	
	script:
		"""
		simulate_InterSIM.R	--dataset_name=${grid.dataset_name} \
			--number=${grid.num_obs} \
			--effect=${grid.effect} \
			--sigma=${grid.sigma} \
			--corr=${grid.corr} \
			--output_format=${output_format} > \
			${grid.dataset_name}_${task.process.tokenize(':')[-1].toLowerCase()}.log
		"""
	// You need extra param to run stub like -stub
	stub:
		"""
		mkdir ${grid.dataset_name}_mae_data
		touch ${grid.dataset_name}_mae_data/experiments.hdf5
		touch ${grid.dataset_name}_mae_data/mae.rds
		touch ${grid.dataset_name}.h5mu
		touch ${grid.dataset_name}.log
		"""

}