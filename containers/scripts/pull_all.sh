#!/bin/bash
# This scripts pulls containers out
function check_container () {
	NAME=$1
	IMG_DIR="$PROJECT_PATH/images"
	IMG=${IMG_DIR}/${NAME}.sif

	if [ ! -d $IMG_DIR ]
	then
		echo "Image dir not exists, create now"
		mkdir -pv $IMG_DIR 
	fi

	if [ -f $IMG ]
	then
		echo "$NAME exists already, skip"
	else
		echo "Container not found, now downloading"
		/bin/bash pull_container.sh docker://tonyliang19/mixdiablo:latest \
				$IMG
		echo "Downloaded ${IMG} at ${IMG_DIR}"
	fi 

}

echo "This script downloads containers to image path, default to $PROJECT_PATH/images, could take long time for first time"

# download mixdiablo
check_container mixdiablo
# download cooperative learning container
check_container cooperative_learning

# Setup pipeline dir
PIPELINE_DIR="${SCRATCH_PATH}/multi-omics-pipeline"
echo "Done, go to $PIPELINE_DIR/README.md for running instructions"