#!/bin/bash
# ==============================================================================
# This is updated script from PBS to SLURM, commands and scripts should
# almost be the same. Although syntax in resource allocations are different
# More on this later
# Author: Tony Liang
# ==============================================================================
#SBATCH --job-name=MESSI-main
#SBATCH --account=st-singha53-1
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=8
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=24G
#SBATCH --output=jup-%x-%j.log
#SBATCH --mail-user=chunqingliang@gmail.com
# ==============================================================================
# Change directory into the job dir
cd $SLURM_SUBMIT_DIR
# Export num threads to be same as cpus_per_task
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Load helper script that loads various ENV variables for later usage
source bin/helper.sh

# Load software environment from compute canada
module load CVMFS_CC # Need to use CC, quite tricky?
module load apptainer/1.1.8
module load java/11.0.16_8
module load nextflow/23.04.3

# Set home, work, cache dir manually
# and other runtime variables for Nextflow related
export NXF_WORK="$PIPELINE_DIR/work"
export NXF_HOME=$PIPELINE_DIR
export NXF_OFFLINE='TRUE'

# Other parameters
export LOG_DIR="$PIPELINE_DIR/results/nxf_logs"
export LOG_NAME=$LOG_DIR/nxf-run_$(date +%Y-%m-%d_%H-%M-%S).log

# ==============================================================================
# SLURM with CC does not favor compute canada, so have to directly use nextflow 
# from loading module

# activate the conda env
#conda activate ${ENV_DIR}
# Check setup of paths
eval nxf=$(which nextflow) && echo -e "\nThis is path to nextflow: $nxf"
eval curr_java=$(which java) && echo -e "\nThis is path to java: $curr_java"
# run the actual pipeline
echo -e "\nStarting now"

# Some variables to edit
NXF_SCRIPT="main.nf"
PROFILE=arc_slurm
CONFIG_FILE=MESSI.config

# Actual runner
nextflow -log ${LOG_NAME} --config ${CONFIG_FILE} \
          run ${NXF_SCRIPT} \
         -profile ${PROFILE} \
# deactivate conda deactivate
#conda deactivate
echo -e "\nDone"