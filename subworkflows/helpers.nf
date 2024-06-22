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
    log.info """
        MESSI PIPELINE
        ==============
        train_data : ${params.train_data}
        outdir     : ${params.outdir}
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