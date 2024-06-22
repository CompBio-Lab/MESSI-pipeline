#!/bin/bash

# Env variables (replace yours here if you want to use different names)
# most directories listed here would be created for you
# Host related

# PROJ_NAME is direcly related with the github repo name
# Might need to make this more robust
#export PROJ_NAME=multi-omics-pipeline
#export ALLOC='st-singha53-1' # $(print_members | grep -o 'st-.*')
#export SCRATCH_PATH=/scratch/${ALLOC}/${USER}
#export PROJECT_PATH=/arc/project/$ALLOC/${USER}/${PROJ_NAME}
# Virtual env related
#export IMG_PATH=${PROJECT_PATH}/apptainer_images
# Project related
#export PIPELINE_DIR=${SCRATCH_PATH}/${PROJ_NAME}
#export SCRIPT_DIR=${PIPELINE_DIR}/bin
#export CONTAINER_NAMES=${PIPELINE_DIR}/containers/names.md

# Helper functions for other script usages
# custom_command() {
#     if [[ $1 != "" ]]
#     then
#         eval $1
#     else
#         echo "provide custom command to fix"
#     fi
# }

# check_dir() {
#     if [ ! -d $1 ]
#     then
#         echo "$1 does not exists, creating now."
#         mkdir -pv $1
#     fi
# }

# check_file() {
#     local DIR_NAME=$(dirname $1)
#     local FILE_NAME=$(basename $1)
#     # check if file exists or not
#     if [ ! -f $1 ]
#     then
#         custom_command $2
#     # if exists then print which dir is the file located at
#     else
#         echo "$FILE_NAME exists already, located at $DIR_NAME"
#     fi
# }

# check_bin() {
#     local DIR_NAME=$(dirname $1)
#     local FILE_NAME=$(basename $1)
#     # check if binary exists or not
#     if ! command -v $1 &> /dev/null
#     then
#         echo -e "${FILE_NAME} not found, trying to run custom command/function \
#         \n$(custom_command $2) "
#     else
#         echo "Found ${FILE_NAME} at ${DIR_NAME}"
#     fi
# }

# check_container() {
# 	local NAME=$1
# 	IMG=$2/${NAME}.sif
# 	ACTION="apptainer pull --name $IMG docker://tonyliang19/$NAME:latest"
# 	check_file $IMG '$ACTION'
# }

# # parse shell script and read documentation within a block surrounded
# # of `#` start and end. 
# print_document() {
#     local script_file="${BASH_SOURCE[1]}"

#     if ! script_content=$(<"$script_file"); then
#         echo "Failed to read script file: $script_file"
#         return 1
#     fi

#     local consecutive_hashes=0

#     while IFS= read -r line; do
#         if [[ $line =~ ^#+$ ]]; then
#             if ((consecutive_hashes == 0)); then
#                 consecutive_hashes=${#line}
#             elif (( ${#line} == consecutive_hashes )); then
#                 break
#             fi
#         elif ((consecutive_hashes > 0)); then
#             echo "${line#"#"}"
#         fi
#     done <<< "$script_content"

#     echo # empty new line for additional print statements in elsewhere
# }

