/*
    This process aims to simulate the data, takes in a map/dictionary of 
    parameters to control the data-generating process.

    Input:  val(grid), combination of parameters
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

process SIMULATE_MVN_DATA {
	// Vars stuff
	//def isRemote = workflow.containerEngine == 'apptainer' && !workflow.profile == 'standard'
	debug false
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	// process metadata and configs
	tag "${grid.dataset_name}"
	label 'process_medium'
	container "${ onSockeye ? 
		'save_simulate.sif' : 
		'tonyliang19/save_simulate:latest' }"
	label 'mae_mu'
	publishDir (
		path: "${params.outdir}/${task.process.tokenize(':')[-1].toLowerCase()}/${grid.dataset_name}",
		saveAS: { file },
		mode: 'copy',
		overwrite: true
	)
	// Input goes here
	input:
		val  grid 					// Combinations of parameters, key-value pair, access element by grid.xxx
	// Possible output for downstream
	output:
		// The optional MUST be true here, since it should output one of MAE or MuData at a time
		tuple val(grid.dataset_name), path("${grid.dataset_name}*mae*"), 	 emit: sim_mae
		tuple val(grid.dataset_name), path("${grid.dataset_name}*.h5mu"),  emit: sim_mu
		tuple val(grid.dataset_name), path('*.log'),									emit: sim_log
	
	script:
		"""
		echo -e "\nThis is try ${grid.dataset_name}"
		simulate_data.R	--dataset_name=${grid.dataset_name} \
			--number=${grid.num_obs} \
			--num_predictors=${grid.num_predictors} \
			--block_num=${grid.block_num} \
			--latent_predictors=${grid.latent_predictors} \
			--sigma=${grid.sigma} \
			--sy=${grid.sy} \
			--sp=${grid.sp} \
			--u_std=${grid.u_std} \
			--fct_str=${grid.fct_str} > \
			${grid.dataset_name}_${task.process.tokenize(':')[-1].toLowerCase()}.log
		echo -e "\nDone with ${grid.dataset_name}"
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