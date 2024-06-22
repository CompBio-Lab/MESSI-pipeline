#!/bin/bash

# ============================================================================
# This is a wrapper script that triggers a SLURM BATCH script, hence most 
# logics are in the other script. Here is more for parsing command line args
#
# Author: Tony Liang
# ============================================================================

# Locates dir of this script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LAUNCHER_SCRIPT=${SCRIPT_DIR}/launch_MESSI_pipeline.sh
# The hidden env file 
ENV_FILE=${SCRIPT_DIR}/.env
# Check if file exists or not
if [ ! -f ${ENV_FILE} ]; then
    echo "missing .env file"
    exit 1
else
    set -o allexport
    source .env # This sources the .env file
    set +o allexport
    if [ "${ALLOCATION_CODE}" = "REPLACE" ] || [ "${MAIL_USER}" = "REPLACE" ]; then
      echo -e "\nERROR: Did not change ALLOCATION_CODE or MAIL_USER\n"
      exit 1
    fi
fi

# Then could actually call the pipeline
sbatch --account=${ALLOCATION_CODE} --mail-user=${MAIL_USER} ${LAUNCHER_SCRIPT}