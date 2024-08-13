/*
  This workflow is related for all simulations of data, to generate data with known ground-truth, relationships, 
  and properties like noise and signal to access method's robustness.

  Currently available strategies:
    - Multivariate normal from CPLR
    - InterSIM
    - Mosim (TODO)
*/

// Include modules
def simulate_dir = "${modulesDir}/simulation"
include { SIMULATE_MVN_DATA }     from "${simulate_dir}/simulate_mvn_data"
include { SIMULATE_INTERSIM }     from "${simulate_dir}/simulate_intersim"
// Include functions
// include { createSimCombination }  from "${modulesDir}/functions"


process COMPRESS_DATA_GZ {
  debug false
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	// process metadata and configs
  tag "${dataset_name}"
	label 'process_low'
	publishDir (
		path: "${params.outdir}/${task.process.tokenize(':')[-1].toLowerCase()}",
		saveAS: { file },
		mode: 'copy',
		overwrite: true
	)

  // These are required to handle to symlink from MAE data
  stageInMode 'copy'
  stageOutMode 'copy'

  input:
    tuple val(dataset_name), path(mae_path), path(mu_path)
  output:
    path("*.tar.gz"), emit: ch_sim_datasets
  
  script:
    """
    mkdir -p ${dataset_name}
    cp -r ${mae_path} ${dataset_name}
    cp ${mu_path} ${dataset_name}
    
    tar -czf ${dataset_name}.tar.gz ${dataset_name}
    """
}


workflow SIMULATION {
  // WORKFLOW PARAMS
  dataset_base_name   = params.dataset_base_name
  output_format       = params.output_formats
  num_obs             = params.num_obs
  y_name              = params.y_name
  // Strategy of simulation
  skip_sim_MVN        = params.skip_sim_MVN
  skip_sim_intersim   = params.skip_sim_intersim

  // Main code entrance
  main:
    // The simulation relies on a grid of parameters to simulate represented a groovy map
    /*
      For example:
      grid = [ [ param1: ... , param2: ... , paramn: ...] , ... ]
      
      This way for each full param set in the grid, process could access those values by 
      its key names like param1, param2, and so on.

      NOTE: Some grid have less keys since certain simulation strategy do no support various
      parameter, i.e. some only support changing number of observations and not number of variables

      big_grid = [ n: n1, p: p1, ... , s = 1]
      small_grid = [ n: n1 , ... , s = 1]
    */
    // Create simulation grids from default parameters
    // mvn_sim_grid  = createSimCombination(params)    // Will determine if giving large grid or small grid
                                                          // Combination of parameters of simulation

    //ch_sim_params_comb.view()


    /*
      ========================================================================
      Setup the grid of exploitable params of simulation
      ========================================================================

    */
    
    // Common params
    ch_num_obs      = Channel.fromList(num_obs)
    ch_y_name   = Channel.of(y_name)

    // =====================================================================
    // Make up the grid for InterSIM
    // =====================================================================
    ch_intersim_sigma = Channel.fromList(params.intersim_sigma)
    ch_intersim_corr = Channel.fromList(params.intersim_corr)
    ch_intersim_effect = Channel.fromList(params.intersim_effect)

    // Assign to map for easy access later
    Channel.of(dataset_base_name)
      .combine(ch_num_obs)
      .combine(ch_intersim_effect)
      .combine(ch_intersim_sigma)
      .combine(ch_intersim_corr)
      .map { m -> 
        [ dataset_name: "${m[0]}_strategy-intersim_n-${m[1]}_effect-${m[2]}_sigma-${m[3]}_corr-${m[4]}", 
          num_obs: m[1], effect: m[2], sigma: m[3], corr: m[4] ]
      }
      .set { intersim_grid }
    
    // =====================================================================
    // Make up the grid for cplr mvn
    // =====================================================================
    ch_mvn_num_predictors = Channel.fromList(params.num_predictors)
    ch_mvn_block_num      = Channel.fromList(params.block_num)
    ch_mvn_latent_pred    = Channel.fromList(params.latent_predictors)
    ch_mvn_sigma          = Channel.fromList(params.mvn_sigma)
    ch_mvn_sy             = Channel.fromList(params.sy)
    ch_mvn_sp             = Channel.fromList(params.sp)
    ch_mvn_u_std          = Channel.fromList(params.u_std)
    ch_mvn_fct_str        = Channel.fromList(params.fct_str)

    // Assign to map for easy access later
    // 
    Channel.of(dataset_base_name)
      .combine(ch_num_obs)
      .combine(ch_mvn_num_predictors)
      .combine(ch_mvn_sigma)
      .combine(ch_mvn_block_num)
      .combine(ch_mvn_latent_pred)
      .combine(ch_mvn_sy)
      .combine(ch_mvn_sp)
      .combine(ch_mvn_u_std)
      .combine(ch_mvn_fct_str)
      .map { m -> 
          [ dataset_name: "${m[0]}_strategy-mvn_n-${m[1]}_p-${m[2]}_sigma-${m[3]}_j-${m[4]}_latp-${m[5]}_sy-${m[6]}_sp-${m[7]}_ustd-${m[8]}_fctstr-${m[9]}", 
            num_obs: m[1], num_predictors: m[2], sigma: m[3], block_num: m[4], latent_predictors: m[5], sy: m[6], sp: m[7], u_std: m[8], fct_str: m[9]
          ]
      }
      .set { mvn_sim_grid }
    
    // Assign to map for easy access later

    /* 
      ========================================================================
      ACTUAL RUNNERS
      ========================================================================
    */
    
    // 1. When strategy is intersim pkg of simulation
    ch_intersim = Channel.empty()
    if (!skip_sim_intersim) {
      // TODO: need to add their right params
      SIMULATE_INTERSIM ( intersim_grid, output_format )
      ch_intersim = SIMULATE_INTERSIM.out.sim_mae.join(SIMULATE_INTERSIM.out.sim_mu)
    }
    // 2. When strategy is cplr's mvn simulation
    ch_mvn = Channel.empty()
    if (!skip_sim_MVN) {
      // TODO: need to add their right params
      SIMULATE_MVN_DATA ( mvn_sim_grid, output_format )
      ch_mvn = SIMULATE_MVN_DATA.out.sim_mae.join(SIMULATE_MVN_DATA.out.sim_mu)
    }
  
    // Lastly mix these results
    Channel.empty()
            // TODO: Need to make sure they're mixable and have similar cardinality of arg in each channel
            // prefarably have something to say what is the strategy, is simulated or not
            // Mix each strategy together
            .mix( ch_intersim )
            .mix( ch_mvn )
            .set { ch_sim_datasets }

    COMPRESS_DATA_GZ ( ch_sim_datasets )

    // For each of these channels, we then compress them as tar.gz
    // COMPRESS_DATA_GZ ( ch_sim_datasets )
  emit:
    ch_sim_datasets = COMPRESS_DATA_GZ.out.ch_sim_datasets
}
