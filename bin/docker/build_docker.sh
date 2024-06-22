#!/bin/bash
#------------------------------------------------------------------------------
# This scripts builds each of dockerfile found in the build directory (default to 
# ~/multi-omics-pipeline/containers/dockerfiles). Note each building is quitely
# so you would only see the build id.
#------------------------------------------------------------------------------

# CLI parser to read arguments into this script
while [ $# -gt 0 ]; do
    case "$1" in
        --dockerfiles=*)
        DOCKERFILES="${1#*=}"
        ;;
        --directory=*)
        BUILD_DIR="${1#*=}"
        ;;
        --username=*)
        DOCKER_USER="${1#*=}"
        ;;
    *)
        printf "***************************\n"
        printf "* Error: Invalid argument.*\n"
        printf "***************************\n"
        exit 1
    esac
    shift
done

# Extensions for dockerfiles (fixed)
EXT=".Dockerfile"
# For each dockerfile build them with tag DOCKER_USER/IMG_NAME:latest
# building under the dir the dockerfiles were found
for DF in ${DOCKERFILES};
do 
    IMG_NAME=$(basename ${DF} ${EXT})
    TAG="$DOCKER_USER/${IMG_NAME}:latest"
    echo -e "\nBuilding ${IMG_NAME}"
    docker build --quiet --file "${DF}" --tag "${TAG}" "${BUILD_DIR}"
    echo -e "\nFinish building ${IMG_NAME}"
done

# # Remove previous dangling images
echo -e "\nCleaning previous old image tags"
docker rmi $(docker images -q -f dangling=true) 2>/dev/null || (echo "No image to delete" && exit 1)
