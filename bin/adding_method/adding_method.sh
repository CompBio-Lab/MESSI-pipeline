#!/bin/bash

# Use this script to call the wrapper script for adding a method
# into MESSI, adopted from nfcore/tools


# This uses the host python
SRC_NAME="adding_method.py"
# Get the full path of the script
SCRIPT_PATH=$(realpath $0)
# Get the directory of the script
SCRIPT_DIR=$(dirname $SCRIPT_PATH)
# Navigate up to the PROJECT ROOT
PROJECT_ROOT_DIR=$(dirname $(dirname $SCRIPT_DIR))
# Python binary
PYTHON_BIN=python
# ARGS for the script
NAME="logit_git"
LANGUAGE="R"
DOCKER_USER="abcdef"

# Then execute the command
${PYTHON_BIN} "${SRC_NAME}" --method=${NAME}  \
  --language=${LANGUAGE} \
  --outdir=${PROJECT_ROOT_DIR} \
  --docker_user=${DOCKER_USER}
#echo ${PROJECT_ROOT_DIR}
