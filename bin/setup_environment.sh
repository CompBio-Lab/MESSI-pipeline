#!/bin/bash

# This arg is directly provided from the Makefile
PROJECT_ROOT_DIR=$1
ENV_FILE="${PROJECT_ROOT_DIR}/.env"
DEF_VAL="FILL_IN"
# This loads the .env file under the root dir of the project
if [ ! -f ${ENV_FILE} ]; then
  echo "You have not created the .env file yet!"
  exit 1
else
  set -o allexport
  source ${ENV_FILE}
  set +o allexport
fi

# Check if ALLOCATION CODE is provided or not
if [ ${ALLOCATION_CODE} == ${DEF_VAL} ]; then
  echo "Allocation code have not provided yet in the .env file"
  echo "Please update it!"
  exit 1
fi


# ============================================================================
# First check if image dir exists and all images are loaded are not
APPTAINER_IMAGE_CACHE_DIR="/arc/project/${ALLOCATION_CODE}/${USER}/MESSI-apptainer-images"
if [ ! -d ${APPTAINER_IMAGE_CACHE_DIR} ]; then
  echo "Dir not exists yet, creating now at: "
  echo ${APPTAINER_IMAGE_CACHE_DIR}
  mkdir -p ${APPTAINER_IMAGE_CACHE_DIR}
fi
# -------------------------------------------------
# Function to check container
check_container() {
	local NAME=$1
  local CACHE_DIR=$2
	local IMG=$CACHE_DIR/${NAME}.sif
  local IMAGE_URI="docker://tonyliang19/${NAME}:latest"
  # For each container if the IMG not exist, then we pull it
  if [ ! -f ${IMG} ]; then
    # NOTE: this only works on sockeye now
    module purge && module load CVMFS_CC
    module load apptainer
    echo -e "\n${IMG} not found, pulling it now"
	  apptainer pull --name ${IMG} ${IMAGE_URI}
  else
    echo "$(basename ${IMG}) exists already, skipped"
  fi
}
# Now check if all relevant images are there, this checks the names under 
# containers/names.md
# File to read in the containers names
DELIMITER=$'\n'
CONTAINER_NAMES_FILE=${PROJECT_ROOT_DIR}/containers/names.md
read -d '' -r -a names < ${CONTAINER_NAMES_FILE}
for CONTAINER in "${names[@]}"
do
  # if image not exists under cache dir, then pulled from remote
  # NOTE: this requires internet
  check_container ${CONTAINER} ${APPTAINER_IMAGE_CACHE_DIR}
done




# ============================================================================
# Instructions to recreate the pipeline
# ============================================================================

echo -e "\nFinished setting up environment\n"
