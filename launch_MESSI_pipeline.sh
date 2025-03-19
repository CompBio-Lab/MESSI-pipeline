#!/bin/bash
# =============================================================================
# This scripts launches the MESSI pipeline to benchmark ML, DL, and statiscal
# learning methods for biomarker identifications using multiomics data
#
# Itself starts a nextflow pipeline that instantiate various more complex
# workflows that has its own resources specifications, designed to run on HPC
# clusters.
#
# NOTE: this only works on UBC ARC sockeye, which requires an allocation code
# to able to deducte resources cost to run the pipeline.
#
# Author: Tony Liang
# ==============================================================================
#SBATCH --job-name=MESSI-main
#SBATCH --time=1-12:00:00
#SBATCH --cpus-per-task=6
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=4G
#SBATCH --output=%x-%j.log
#SBATCH --mail-type=ALL
# ==============================================================================

# Change directory into the job dir
cd $SLURM_SUBMIT_DIR

# =============================================================================
# 1. Environments related imports
# This first unload existing modules, since they might conflict with CC modules
module purge
module load CVMFS_CC
# Related dependencies
# THESE ARE OUTDATED FROM CC
# module load apptainer/1.1.8
# module load java/11.0.16_8
# module load nextflow/23.04.3
# THESE ARE NEWER VERSIONS
module load apptainer/1.3.4
module load java/17.0.6
module load nextflow/24.04.4
# Source the load script with env vars setup
#source bin/helper.sh
# =============================================================================
# 2. Set nextflow related env vars so this works on Sockeye
# Sockeye's compute node do not have internet access, so we need to set
# and offline option
# And pull the containers required using the test profile
PIPELINE_DIR=$(eval pwd)
# AS per nextflow expert, work/ CANNOT be under /tmp
export NXF_WORK="${PIPELINE_DIR}/work"
export NXF_HOME="${PIPELINE_DIR}"
#export NXF_WORK=${TMPDIR}/work
#export NXF_HOME=${TMPDIR}
export NXF_OFFLINE='true'
# =============================================================================
# 3. Options to use for the pipeline
# The NXF script to run, located on the repo root directory
NXF_SRC_MAIN=$PIPELINE_DIR/main.nf
# Profile order matters, since the later one overrides the prior ones
#PROFILE=sockeye,simulated_data
PROFILE=sockeye,real_data
# Or use this one for development usage
#PROFILE=sockeye,test,debug
#PARAMS_FILE=remote_params.yaml
# Modify this option if you want to run several times
# Could be done in a for-loop fashion for different OUTDIR
timestamp=$(date +"%Y%m%d_%H%M%S")
OUTDIR=${timestamp}-job${SLURM_JOB_ID}-MESSI_results
#SAMPLESHEET=data/samplesheet_feat_selection.csv
SAMPLESHEET=data/samplesheet_test_full.csv
#SAMPLESHEET=data/samplesheet_test_small.csv
#SAMPLESHEET=data/samplesheet_325-405.csv
echo "Running pipeline with ${NXF_SRC_MAIN}"
echo "Running data under '${SAMPLESHEET}'"
# =============================================================================
# 4. Run the pipeline on the work dir
# The ansi-log option is used for redirecting output
nextflow run ${NXF_SRC_MAIN} \
  -profile ${PROFILE} \
  --outdir ${OUTDIR} \
  --samplesheet ${SAMPLESHEET} \
  -ansi-log false
# =============================================================================
# 5. Compress output results and move back to submitted directory
#cd ${TMPDIR}
#tar -czf ${timestamp}-MESSI_results.tar.gz $(basename ${OUTDIR})
#echo "Moving compressed gz to ${PIPELINE_DIR}"
#mv ${timestamp}-MESSI_results.tar.gz ${PIPELINE_DIR}
