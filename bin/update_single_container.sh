#!/bin/bash

##############################################################################
# This script pulls down a pre-built container (created from the authors and other community users) that
# could be then used in the pipeline. These containers should be archival, read-only mode
# Usage: pull_container.sh IMAGE_NAME URI
##############################################################################

man() {

cat << EOF

This script pulls down a pre-built container that could be used in the nextflow pipeline,
whereas they should be archival, read-only mode.

Usage: $0 IMAGE_NAME URI

Arguments:
  IMAGE_NAME	Name you want to give to the container, dont need the .sif
		and will be stored to $PROJECT_PATH/$PROJ_NAME/apptainer_images
  URI		Docker hub registry that stores the container

EOF
}

if [ "$#" -ne 2 ]; then
	#echo "Usage: $0 IMAGE_NAME DOCKER_HUB_URL" >&2
	man >&2
	exit 1
fi

# load required modules
module load gcc apptainer

# pull the pre-built container from Docker Hub
IMG="$PROJECT_PATH/multi-omics-pipeline/apptainer_images/$1.sif"
apptainer pull --force --name "$IMG" "$2"



