#!/bin/bash

# Use this script to call the wrapper script for adding a method
# into MESSI, adopted from nfcore/tools


# This uses the host python
SRC_NAME="adding_method.py"
# Get the full path of the script
SCRIPT_PATH=$(realpath $0)
# Get the directory of the script
SCRIPT_DIR=$(dirname $SCRIPT_PATH)
# Parse the python script that holds actual logic of creating files from template
PYTHON_SRC="${SCRIPT_DIR}/adding_method.py"

# Navigate up to the PROJECT ROOT
PROJECT_ROOT_DIR=$(dirname $(dirname $SCRIPT_DIR))
# Python binary
PYTHON_BIN=python
# ARGS for the script
NAME="logit_abc"
LANGUAGE="R"
DOCKER_USER="abcdef"

# Then execute the command
echo "Adding ${NAME} into MESSI"

${PYTHON_BIN} "${PYTHON_SRC}" --method=${NAME}  \
  --language=${LANGUAGE} \
  --outdir=${PROJECT_ROOT_DIR} \
  --docker_user=${DOCKER_USER}
#echo ${PROJECT_ROOT_DIR}
