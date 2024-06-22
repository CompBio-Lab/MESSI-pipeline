#!/bin/bash

#------------------------------------------------------
# This script reads all required to update dockerfiles
# stored in certain directory, build each of those,
# clean the previous danged ver image and publish
# to relevant file.
#------------------------------------------------------

# CLI parser to read arguments into this script
while [ $# -gt 0 ]; do
    case "$1" in
        #If force update, then update all
        --force-update=*)
        FORCE_UPDATE="${1#*=}"
        ;;
        --build-only=*)
        BUILD-ONLY="${1#*=}"
        ;;
    *)
        printf "***************************\n"
        printf "* Error: Invalid argument.*\n"
        printf "***************************\n"
        exit 1
    esac
    shift
done

PROJECT_ROOT="$(dirname $(dirname $(readlink -f "$0")))"
# Dir to read scripts related to dockerfile
DOCKER_SRC_DIR="$(dirname $0)/docker"
# Dir to read Dockerfiles (actual image definitions)
DOCKERFILES_DIR="$PROJECT_ROOT/containers/dockerfiles"
# Docker Username
DOCKER_USERNAME="tonyliang19"

# Build each dockerfile to image
BUILD_SRC="${DOCKER_SRC_DIR}/build_docker.sh"

# If force_update not empty, then updates all dockerfiles
if [ ! -z $FORCE_UPDATE ]; then
    # Relevant Dockerfiles depend on force update option
    echo "Building all dockerfiles"
    DOCKERFILES="$(find ${DOCKERFILES_DIR} \
                    -type f -name *.Dockerfile \
                    ! -name *template* \
                    ! -name smgr* ! -name rpy_muex* )"
# Otherwise only those modified dockerfiles are built (requires git)
else
    # If no files modified, then just quit the program
    DOCKERFILES=$(git status $DOCKERFILES_DIR --porcelain | awk '{print $2}')
    if [[ ! $DOCKERFILES ]]; then
        echo "No dockerfile modified, quiting build process" && exit 1
    
    else
        echo "Building only modified dockerfiles"
    fi
fi

#============================================================
# Build and pushing blocks, cli option to control if to build
# only and not push or both actions executed

bash "${BUILD_SRC}" --dockerfiles="${DOCKERFILES}" \
                    --directory="${DOCKERFILES_DIR}" \
                    --username="${DOCKER_USERNAME}"
if [ ! -z $BUILD_ONLY ]; then
    echo -e "\nFinish building dockerfiles" && exit 1
else
    # Push each dockerfile to image
    PUSH_SRC="${DOCKER_SRC_DIR}/push_docker.sh"
    bash "${PUSH_SRC}"  --username="${DOCKER_USERNAME}" \
                        --dockerfiles="${DOCKERFILES}"
    echo -e "\nFinish pushing images to docker registry"
fi