#!/bin/bash

# ============================================================================
# This is a wrapper script that triggers a SLURM BATCH script, hence most 
# logics are in the other script. Here is more for parsing command line args
#
# Author: Tony Liang
# ============================================================================


# Load modules?
#module load apptainer/1.3.4
#module load java/17.0.6
#module load nextflow/24.10.2
module load apptainer/1.3.5
module load java/21.0.1
module load nextflow/24.10.2

#  1) gcccore/.12.3 (H)   5) libfabric/1.18.0       9) flexiblas/3.3.1  13) java/21 -> java/21.0.1
#  2) gcc/12.3      (t)   6) pmix/4.2.4            10) imkl/2023.2.0    14) nextflow/24.10.2
#  3) hwloc/2.9.1         7) ucc/1.2.0             11) CVMFS_CC/2023
#  4) ucx/1.14.1          8) openmpi/4.1.5    (m)  12) apptainer/1.3.5



# pick a writable dir — adjust to your HPC's scratch/work path
export NXF_HOME=$SCRATCH_PATH/.nextflow

# keep these off /home too
export NXF_WORK=./work
export NXF_TEMP=$SCRATCH_PATH/nxf_tmp
export NXF_PLUGINS_DIR=$NXF_HOME/nxf_plugins
export CAPSULE_CACHE_DIR=$SCRATCH_PATH/.capsule   # Java/Capsule launcher cache

# Java itself may also try to write to $HOME; give it a writable tmp
export JAVA_TOOL_OPTIONS="-Djava.io.tmpdir=/scratch/tliang19/tmp"

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
#export NXF_PLUGINS_DIR=./nxf_plugins
#export NXF_OFFLINE=true
export NXF_DISABLE_CHECK_LATEST='true'


#export NXF_TEMP="/data1/tliang19/tools/nextflow/nf-tmp"
#SELECT_FEAT='true' # Or use 'false'
SELECT_FEAT='false'

CSV_FILE="data/samplesheet_momix.csv"
#CSV_FILE="data/local_samplesheet.csv"
#CSV_FILE="data/samplesheet_bulk.csv"
#CSV_FILE="data/samplesheet_multimodal.csv"
#CSV_FILE="data/samplesheet_htx_only.csv"
#CSV_FILE="data/samplesheet_covid_only.csv"
#CSV_FILE="data/all_datasets.csv"
#CSV_FILE="data/samplesheet_test_small.csv"
F="false"
T="true"

FILTER="1" # True in nextflow
#FILTER="0"

K_FOLD_NUMBER=2
#K_FOLD_NUMBER=5
#SK_MODS="Logit,XGBoost"
#SK_MODS="Logit,MLP"

#MAX_MEM="4G"
MAX_MEM="6G"


#PROFILE="standard,docker,test"
PROFILE="arc_local,apptainer"
# Specify number of CPUs and memory
nextflow run main.nf \
  -profile $PROFILE \
  -resume \
  --single_modality_mode $F \
  --samplesheet ${CSV_FILE} \
  --filter_low_var $FILTER \
  --outdir results \
  --skip_rgcca $F \
  --skip_mofa $F \
  --skip_sklearn $F \
  --skip_caret_multimodal $F \
  --skip_diablo $F \
  --skip_cplr $F \
  --skip_mogonet $F \
  --skip_integrao $F \
  --pipeline_dir ./ \
  --k_fold_number $K_FOLD_NUMBER \
  --selectFeature $F \
  --publish_relevant $F
