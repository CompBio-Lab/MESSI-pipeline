#!/bin/bash

#------------------------------------------------------------------------------
# This scripts push each of built docker image to the docker registry
# of provided docker username.
#------------------------------------------------------------------------------

# CLI parser to read arguments into this script
while [ $# -gt 0 ]; do
    case "$1" in
        --dockerfiles=*)
        DOCKERFILES="${1#*=}"
        ;;
        --username=*)
        DOCKER_USERNAME="${1#*=}"
        ;;
    *)
        printf "***************************\n"
        printf "* Error: Invalid argument.*\n"
        printf "***************************\n"
        exit 1
    esac
    shift
done

echo "Need to test docker login non interactively later"
#docker login --username=$DOCKER_USERNAME --password-stdin $DOCKER_HOST

EXT=".Dockerfile"
# For each dockerfile build them with tag DOCKER_USER/IMG_NAME:latest
# building under the dir the dockerfiles were found
for DF in ${DOCKERFILES};
do 
    IMG_NAME=$(basename ${DF} ${EXT})
    TAG="$DOCKER_USER/${IMG_NAME}"
    echo -e "\nPushing ${IMG_NAME}"
    # Timer to evaluate time to build x image
    start=$(date +%s)
    docker push "${TAG}"
    end=$(date +%s)
    runtime=$((end-start))
    echo -e "\nFinish pushing ${IMG_NAME}, time=${runtime}s"
done

echo -e "\nDone for pushing"
