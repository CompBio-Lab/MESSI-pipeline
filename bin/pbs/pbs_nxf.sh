#!/bin/bash
# This is are the allocation specifications for the PBS job

###############################################################################
# For more information about resources used in each workflow
# see ./nextflow.config and ./configs/remote.config
# 
# For here, we are using using the following resources
# 1 node of 8 cpu each of 16gb
# could use less resources, since this job to submit pipeline,
# where actual pipeline is executed through separate jobs
# 
# Minimal resource required here, since it spawns child jobs per processes
# 2 CPUS gets to 2m ~ 3m run time with minimal test example
# 8 CPUS gets to 1m and less of run time with minimal test example
# So default to it 8 for now

###############################################################################
#PBS -l walltime=06:00:00,select=1:ncpus=8:mem=32gb
#PBS -N NXF_HEAD
#PBS -A st-singha53-1
#PBS -m e
#PBS -M tliang19@student.ubc.ca
#PBS -j oe
###############################################################################

# Change to working dir (job dir)
cd $PBS_O_WORKDIR

# Load conda setup
source ~/.bashrc
# Load helper script that loads various ENV variables for later usage
source bin/helper.sh

# Loading modules at specfic version
module load gcc/9.4.0
module load apptainer/1.1.9
module load openjdk/11.0.8_10

# Set home, work, cache dir manually
# and other runtime variables for Nextflow related
export NXF_WORK="$PIPELINE_DIR/work"
export NXF_HOME=$PIPELINE_DIR
export NXF_OFFLINE='TRUE'

export LOG_DIR="$PIPELINE_DIR/results/nxf_logs"
export LOG_NAME=$LOG_DIR/nxf-run_$(date +%Y-%m-%d_%H-%M-%S).log
# activate the conda env
conda activate ${ENV_DIR}
# Check setup of paths
eval nxf=$(which nextflow) && echo -e "\nThis is path to nextflow: $nxf"
eval curr_java=$(which java) && echo -e "\nThis is path to java: $curr_java"
# run the actual pipeline
echo -e "\nStarting now"

# Script to run
#NXF_SCRIPT=${1:-minimal.nf}
NXF_SCRIPT="main.nf"

nextflow -log ${LOG_NAME} run ${PIPELINE_DIR}/${NXF_SCRIPT} \
         -profile arc_pbs
# deactivate conda deactivate
conda deactivate
echo -e "\nDone"