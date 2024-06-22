# =============================================
# Use this Makefile to build image fastly
# with shortcut commands
#
# Examples:
# make image ---> builds from DOCKERFILE
# make push  ---> push current built image
# =============================================
# PARAMETERS TO USE / OVERRIDABLE
# You could everytime change the name of the VARIABLES
# then at the end reverted using git restore, so that
# the file is just as convenient usage and not updating it
# constantly with git.
DOCKERFILE=Dockerfile
USERNAME=tonyliang19
# This could be changed or override at run time like make <target> NAME=new_name
NAME=test
TAG=latest
FULL_IMAGE_NAME=${USERNAME}/${NAME}:${TAG}
help:
	@echo "Run 'make help' to show this message"
	@echo "Run 'make build' to build image from ${DOCKERFILE}"
	@echo "Run 'make push' to push built image"

# Builds the image first, and delete those staled ones
build:
	docker build -t ${FULL_IMAGE_NAME} -f $(DOCKERFILE) .
	@(docker rmi $$(docker images -q -f dangling=true) 2>/dev/null) || (echo "No image to delete" && exit 1)

push:
	docker push ${FULL_IMAGE_NAME}
