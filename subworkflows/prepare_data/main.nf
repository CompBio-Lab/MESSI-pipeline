// Include simulation workflow
include { SIMULATION } from "${subworkflowDir}/simulation"

// Include modules here
def prepare_dir = "${modulesDir}/prepare_data"
include { PREPARE_MAE_DATA  }     from "${prepare_dir}/prepare_mae_data"
include { PREPARE_MU_DATA   }     from "${prepare_dir}/prepare_mu_data"
include { PARSE_METADATA }        from "${prepare_dir}/parse_metadata"
include { UNCOMPRESS_RECORD }     from "${prepare_dir}/uncompress_record"
// More generic utitilies here
def funScript = "${modulesDir}/functions"
include { printBanner }           from "${funScript}"
include { createSimCombination }  from "${funScript}"
// include { calculateSeed }         from "${funScript}"
// include { parseDataDirs }         from "${funScript}"
// Logging helpers
def logRunSimple(boolean runSimple) {
  if (runSimple) {
      log.info "\nRunning on simple mode for simulation"
  } else {
    log.info "Creating huge grid of params for simulation"
  }
}



// This workflow should handle all raw data input read in
// either treating real data parsing, or simulating data
workflow PREPARE_DATA {
    // Load parameters used for the workflow
    // ch_sim_params_comb  = createSimCombination(params)    // Will determine if giving large grid or small grid
    //                                                       // Combination of parameters of simulation
    // ch_output           = Channel.fromList(               // Output format MAE and MuData
    //                         params.output_formats
    //                       )
    skip_simulation      = params.skip_simulation               // Skip simulations or not (default: true)
    runSimple            = params.runSimple
    filter_low_var       = params.filter_low_var  // Filter the low variance features (default: "0")

    skip_handling_real_data = false
  /* Workflow starts here */
  // Workflow required input
  take:
    samplesheet
  main:
    // Do some logging first
    printBanner()
    log.info "Running prepare data"
    //log.info "Read in real data from: ${real_data_dir}"
    /*
      Notice this is the simulated data that should be appended together  with real data later
      It is optional to simulate or to not simulate.

      Channel of [dataset_name, mae_path, mu_path]
      */

    // sim_data = Channel.empty()
    // if (!skip_simulation) {
    //   log.info "Starting simulation"
    //   SIMULATION ( )
    //   sim_data = SIMULATION.out.ch_sim_datasets
    // }

    
    // Read each record of the input samplesheet csv, and emit them as a channel
    // Channel of [dataset_name, mae_path] and Channel of [dataset_name, mu_path]
    Channel.fromPath( samplesheet )
          .splitCsv(header: true)
          .set { data_records }
    
    ch_datasets = Channel.empty()
    if (!skip_handling_real_data) {

      UNCOMPRESS_RECORD ( data_records )

      // // Join by common dataset_name and make it multimap
      UNCOMPRESS_RECORD.out.record
                    .map { it ->
                      [
                        dataset_name: it[0],
                        mae_path: it[1],
                        mu_path: it[2],
                      ]
                    }
                    .multiMap{ it ->
                      mae_pt:  [dataset_name: it.dataset_name, mae_path: it.mae_path]
                      mu_pt:   [dataset_name: it.dataset_name, mu_path: it.mu_path]
                    }
                    .set { real_data }
      /* ===================================================================== */
      // Have a process to check the right format for MAE
      // output MAE back with suitable transformations?
      PREPARE_MAE_DATA  ( real_data.mae_pt, filter_low_var )
      // Have a process to check the right format for MuData
      // output MuData back with suitable transformation?
      PREPARE_MU_DATA   ( real_data.mu_pt, filter_low_var  )
      // TODO: Need to test this bit first
      PREPARE_MAE_DATA.out
                      .mae_data
                      .join(
                        PREPARE_MU_DATA.out.mu_data, by:0
                      )
                      .map { it ->
                        // TODO: this might have a better way to do it?
                        [ dataset_name: it[0], mae_path: it[1], mu_path: it[2] ]
                      }
                      .set { processed_real_data }

      // There is also a process to parse through these datasets and read in their 
      // metadata information like dataset size, number of observations (patients),
      // number of omics, and number of vars per omics
      // TODO: this could be done through R or Python?
      // ch_datasets  = processed_real_data.mix(sim_data)
      ch_datasets = processed_real_data
      // TODO: Might have a better way to dealt this?
      PARSE_METADATA ( 
        ch_datasets.map { it -> it.mae_path }
                   .collect()
      )
      // TODO: Do the conversions later? assume two formats exists now
    }
  emit:
    /*
    Appending real data with simulation data (if any)
    Format:
      Channel of [dataset_name, mae_path, mu_path]
    Size is one of:
      N = n(real_data) + n(simulated_data)
      N = n(real_data)
    */
    ch_datasets  = ch_datasets
}

