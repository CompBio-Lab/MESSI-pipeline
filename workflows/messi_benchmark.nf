/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Local modules
//
include {   helpMessage; printPath; printMetadata; printParameters } from "${subworkflowDir}/helpers"
include {   calculateSeed }      from "${modulesDir}/functions"
include {   CALCULATE_METRICS }  from "${modulesDir}/calculate_metrics"


//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include {  INPUT_CHECK }        from "${subworkflowDir}/input_check"
include {  PREPARE_DATA } 	    from "${subworkflowDir}/prepare_data"
include {  SPLITTING  }		      from "${subworkflowDir}/splitting"
include {  CROSS_VALIDATION }		from "${subworkflowDir}/cross_validation"
include {  FEATURE_SELECTION }  from "${subworkflowDir}/feature_selection"

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


workflow MESSI_BENCHMARK {
  //
  // SUBWORKFLOW: Run prepare_data to transform mae/h5mu accordingly
  //
  PREPARE_DATA ( params.samplesheet ) // Channel of [ dateset_name, mae_path, mu_path ]
  // TODO: fix this here?
  //
  // SUBWORKFLOW: Run feature selection if provided as option
  //
  if ( params.selectFeature ) {
    FEATURE_SELECTION ( PREPARE_DATA.out.mae_data, PREPARE_DATA.out.mu_data )
  } else {
    log.info "Not performing feature selection"
  }

  if ( !params.runPerformanceEvaluation ) {
    log.info "Not running classification performance"
  } else {
      //
      // SUBWORKFLOW: Perform splitting with stratification to the response
      // variable on each dataset
      //
      SPLITTING (	PREPARE_DATA.out.mu_data )
      //
      // SUBWORKFLOW: Perform cross validation for each dataset using these indices
      //
      CROSS_VALIDATION ( PREPARE_DATA.out.mae_data, PREPARE_DATA.out.mu_data, SPLITTING.out.splits_indices )
      //
      // MODULE: Use the output of cross validation to calculate metrics
      //
      CALCULATE_METRICS ( 
        CROSS_VALIDATION.out.csv_results, 
        params.threshold 
      )
  }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
  println "Successfully completed"
  /*
  // This bit cannot be run interactively????, only try when sending as pipeline 
  jsonStr = JsonOutput.toJson(params)
  file("${params.outdir}/params.json").text = JsonOutput.prettyPrint(jsonStr)
  */
  println ( workflow.success ? 
  """
  ===============================================================================
  Pipeline execution summary
  -------------------------------------------------------------------------------

  Run as      : ${workflow.commandLine}
  Started at  : ${workflow.start}
  Completed at: ${workflow.complete}
  Duration    : ${workflow.duration}
  Success     : ${workflow.success}
  workDir     : ${workflow.workDir}
  Config files: ${workflow.configFiles}
  exit status : ${workflow.exitStatus}

  --------------------------------------------------------------------------------
  ================================================================================
  """.stripIndent() : """
  Failed: ${workflow.errorReport}
  exit status : ${workflow.exitStatus}
  """.stripIndent()
  )
}

workflow.onError = {
    println "Error: something went wrong"
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/