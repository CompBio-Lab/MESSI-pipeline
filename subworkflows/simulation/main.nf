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
include { createSimCombination }  from "${modulesDir}/functions"

workflow SIMULATION {
  // WORKFLOW PARAMS
  // Strategy of simulation
  skip_sim_MVN       = true
  skip_sim_intersim  = true

  //
  ch_sim_params_comb  = createSimCombination(params)    // Will determine if giving large grid or small grid
                                                          // Combination of parameters of simulation
  ch_output           = Channel.fromList(               // Output format MAE and MuData
                            params.output_formats
                          )
  main:
    log.info "SIMULATION WORKING ON"

    // 1. When strategy is intersim pkg of simulation
    ch_intersim = Channel.empty()
    if (!skip_sim_intersim) {
      // TODO: need to add their right params
      SIMULATE_INTERSIM ( ... )
      ch_intersim = SIMULATE_INTERSIM.out
    }
    // 2. When strategy is cplr's mvn simulation
    ch_mvn = Channel.empty()
    if (!skip_sim_MVN) {
      // TODO: need to add their right params
      SIMULATE_MVN_DATA ( ... )
      ch_mvn = SIMULATE_MVN_DATA.out
    }
  
    // Lastly mix these results
    Channel.empty()
            // TODO: Need to make sure they're mixable and have similar cardinality of arg in each channel
            // prefarably have something to say what is the strategy, is simulated or not
            // Mix each strategy together
            .mix( ch_intersim )
            .mix( ch_mvn )
            .set { ch_sim_datasets }

  emit:
    ch_sim_datasets = ch_sim_datasets
}