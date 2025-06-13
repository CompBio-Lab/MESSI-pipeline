#!/usr/bin/env nextflow
// Helper functions for main workflow


// For DEBUG purpose process
process printPath {
    debug true	
    script:
    """
    echo This is the scracth path: ${scratchPath}
    echo This is project path: ${projectPath}
    echo This is r dir : ${rDir}
    """
}

// Help message functions
def helpMessage() {
    log.info """

    Usage:
        This is the multi-omics pipeline and helps to find a method of Classification 
        or Regression that suits your omics data or benchmark your method if you have one
        
        To run this pipeline locally:

        nextflow run main.nf -profile local

        To run this pipeline remotely on clusters:

        nextflow run main.nf -profile remote

        Required arguments:
            -profile            local or remote to determine which config
                                file to use and run

        Optional arguments:
            --help              Prints this help message


    Includes other subworkflow here if you wish to add more subworkflows,
    ideally a subworkflow contains other modular files in  modules/

    Uses syntax of the following:
    
    include { <workflow_name> } from "./subworkflow/<workflow_file_without_extension>"

    Notice SPACE is required within in the bracket, it is like bash sourcing variable
    """.stripIndent()
}

//=============================================================================
// WORKFLOW RUN PARAMETERS
def printParameters() {
    println """
    MESSI_BENCHMARK Pipeline Parameters
    ===========================================================================
    This pipeline is designed to benchmark classification methods on multi-omics data.
    ===========================================================================
    Workflow metadata:
    =========================================================================== 
    Pipeline Name   : ${workflow.manifest.name}
    Author          : ${workflow.manifest.author}
    Version         : ${workflow.manifest.version}
    Description     : ${workflow.manifest.description}
    Run Name        : ${workflow.runName}
    Container       : ${workflow.containerEngine}
    Profile         : ${workflow.profile}
    ===========================================================================
    General parameters:
    ===========================================================================
    // Directory to save output files
    outdir              : ${params.outdir}
    pipeline_dir        : ${params.pipeline_dir}
    // Publish final results only and not keep intermediate files
    publish_relevant    : ${params.publish_relevant}
    // Samplesheet containing dataset information
    samplesheet         : ${params.samplesheet}
    // Directory containing data files
    data_dir            : ${params.data_dir}
    // Print help message if true
    help                : ${params.help}
    verbose             : ${params.verbose}
    // Directory to apptainer images (.sif format)
    apptainer_cache_dir : ${params.apptainer_cache_dir}
    ===========================================================================
    Resource parameters:
    ===========================================================================
    // Maximum resources for the workflow
    max_memory                      : ${params.max_memory}
    max_cpus                        : ${params.max_cpus}
    max_time                        : ${params.max_time}
    // Array sizes for different tasks
    // These are used to control how many jobs can run concurrently
    // and how many tasks are grouped together in a single job
    // GPU jobs are typically smaller to avoid GPU queue bottlenecks
    cpu_generic_array_size          : ${params.cpu_generic_array_size}
    cpu_preprocess_array_size       : ${params.cpu_preprocess_array_size}
    cpu_training_array_size         : ${params.cpu_training_array_size}
    cpu_prediction_array_size       : ${params.cpu_prediction_array_size}
    gpu_array_size                  : ${params.gpu_array_size}
    feature_selection_array_size    : ${params.feature_selection_array_size}
    ===========================================================================
    Skip methods parameters:
    ===========================================================================
    skip_cplr      : ${params.skip_cplr}
    skip_diablo    : ${params.skip_diablo}
    skip_rgcca     : ${params.skip_rgcca}
    skip_mogonet   : ${params.skip_mogonet}
    skip_mofa      : ${params.skip_mofa}
    skip_sklearn   : ${params.skip_sklearn}
    ===========================================================================
    Preprocessing parameters:
    ===========================================================================
    // Number of splits to use in cross-validation
    k_fold_number  : ${params.k_fold_number}
    // Directory to save split data
    split_dir      : ${params.split_dir}
    // Whether to filter low variance features
    filter_low_var : ${params.filter_low_var}
    ===========================================================================
    Method related parameters:
    ===========================================================================
    // Number of components to use in component-based methods
    num_comps                   : ${params.num_comps}
    // Connection to the DIABLO design matrix
    diablo_design_connection    : ${params.diablo_design_connection}
    // List of sklearn classifiers to use
    sklearn_claissifer_names    : ${params.sklearn_classifier_names}
    // Threshold for prediction performance evaluation
    threshold                   : ${params.threshold}
    ===========================================================================
    END of MESSI_BENCHMARK Pipeline Parameters
    ===========================================================================
    """.stripIndent()
}
//=============================================================================

//=============================================================================
// WORKFLOW RUN METADATA LOGGING
//=============================================================================
def printMetadata() {

    // ANSI colors
    c_reset = params.mono_logs ? '' : "\033[0m";
    c_bold = params.mono_logs ? '' : "\033[1m";
    c_dim = params.mono_logs ? '' : "\033[2m";
    c_block = params.mono_logs ? '' : "\033[3m";
    c_ul = params.mono_logs ? '' : "\033[4m";
    c_black = params.mono_logs ? '' : "\033[0;30m";
    c_red = params.mono_logs ? '' : "\033[0;31m";
    c_green = params.mono_logs ? '' : "\033[0;32m";
    c_yellow = params.mono_logs ? '' : "\033[0;33m";
    c_blue = params.mono_logs ? '' : "\033[0;34m";
    c_purple = params.mono_logs ? '' : "\033[0;35m";
    c_cyan = params.mono_logs ? '' : "\033[0;36m";
    c_white = params.mono_logs ? '' : "\033[0;37m";
    c_bul = c_bold + c_ul;
    // Has the run name been specified by the user?
    //  this has the bonus effect of catching both -name and --name
    custom_runName = params.name
    if (!(workflow.runName ==~ /[a-z]+_[a-z]+/)) {
        custom_runName = workflow.runName
    }
    // Header log info
    log.info """
    ===========================================================================
    ${workflow.manifest.name} v${workflow.manifest.version}
    ===========================================================================
    """.stripIndent()
    def summary = [:]
    summary['Pipeline Name']    = workflow.manifest.name
    summary['Pipeline Version'] = workflow.manifest.version
    summary['Run Name']                     = custom_runName ?: workflow.runName
    if (workflow.containerEngine) summary['Container'] = "$workflow.containerEngine - $workflow.container"
    summary['Current home']   = "$HOME"
    summary['Current user']   = "$USER"
    summary['Current path']   = "$PWD"
    summary['Output Dir']     = params.outdir
    summary['Launch Dir']     = workflow.launchDir
    summary['Working Dir']    = workflow.workDir
    summary['Script Dir']     = workflow.projectDir
    summary['User']           = workflow.userName
    summary['Config Profile'] = workflow.profile
    if(workflow.profile == 'remote') summary['Max Resources']    = "$params.max_memory memory, $params.max_cpus cpus, $params.max_time time per job"
    log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
    //log.info "${c_block}--------------------------------------------------${c_reset}"
    log.info """
    ===========================================================================
    """.stripIndent()
}