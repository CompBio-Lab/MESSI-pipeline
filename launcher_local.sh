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

# Then call the pipeline here
export NXF_OFFLINE='true'
export NXF_TEMP="/data1/tliang19/tools/nextflow/nf-tmp"
#SELECT_FEAT='true' # Or use 'false'
SELECT_FEAT='false'

#CSV_FILE="data/local_samplesheet.csv"
CSV_FILE="data/samplesheet_bulk.csv"
#CSV_FILE="data/samplesheet_multimodal.csv"
#CSV_FILE="data/samplesheet_htx_only.csv"
#CSV_FILE="data/samplesheet_covid_only.csv"
#CSV_FILE="data/all_datasets.csv"

F="false"
T="true"

FILTER="1" # True in nextflow
#FILTER="0"

#K_FOLD_NUMBER=2
K_FOLD_NUMBER=5
#SK_MODS="Logit,XGBoost"
#SK_MODS="Logit,MLP"

#MAX_MEM="4G"
MAX_MEM="6G"

# Specify number of CPUs and memory
nextflow run main.nf \
  -profile standard,docker,test  \
  --single_modality_mode $T \
  --samplesheet ${CSV_FILE} \
  --filter_low_var $FILTER \
  --outdir results \
  --max_memory $MAX_MEM \
  --skip_rgcca $F \
  --skip_mofa $T \
  --skip_sklearn $T \
  --skip_caret_multimodal $T \
  --skip_diablo $F \
  --skip_cplr $T \
  --skip_mogonet $T \
  --skip_integrao $T \
  --pipeline_dir ./ \
  --k_fold_number $K_FOLD_NUMBER \
  --selectFeature $F \
  --publish_relevant $T \
  -resume
