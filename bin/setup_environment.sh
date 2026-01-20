#!/bin/bash

# This arg is directly provided from the Makefile
PROJECT_ROOT_DIR="${1:-$(pwd)}"
echo -e "Using ${PROJECT_ROOT_DIR} as project root dir\n"
ENV_FILE="${PROJECT_ROOT_DIR}/.env"
#echo "ENV file is: ${ENV_FILE}"
DEF_VAL="REPLACE"
# This loads the .env file under the root dir of the project
if [ ! -f ${ENV_FILE} ]; then
  echo "You have not created the .env file yet!"
  exit 1
else
  set -o allexport
  source ${ENV_FILE}
  set +o allexport
fi

# Helper function to check if a variable is set and not equal to DEF_VAL

check_var() {

  local var_name="$1"

  local var_value="${!var_name}"  # Indirect expansion to get value of variable

  if [ -z "${var_value}" ] || [ "${var_value}" == "${DEF_VAL}" ]; then

    echo "$var_name has not been provided yet in the .env file"

    echo "Please update it!"

    exit 1

  fi

}


# Check if ALLOCATION CODE is provided or not
check_var "ALLOCATION_CODE"
# Check if MAIL user has provided or not
check_var "MAIL_USER"
# Check if apptainer image cache dir exist
check_var "APPTAINER_IMAGE_CACHE_DIR"

# ============================================================================
# First check if image dir exists and all images are loaded are not
#APPTAINER_IMAGE_CACHE_DIR="/arc/project/${ALLOCATION_CODE}/${USER}/MESSI-apptainer-images"
if [ ! -d "${APPTAINER_IMAGE_CACHE_DIR}" ]; then
  echo "Dir not exists yet, creating now at: "
  echo "Creating the cache dir:  ${APPTAINER_IMAGE_CACHE_DIR}"
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
